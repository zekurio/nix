"""Keep original-language, German, English and untagged tracks, then clean metadata."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
from urllib.request import Request, urlopen

import pycountry


FONT_MIMES = {
    "application/x-truetype-font", "application/x-font-ttf",
    "application/x-font", "application/font-sfnt", "application/vnd.ms-opentype",
    "application/x-font-opentype", "application/font-woff",
}
EXTENSIONS = {".mkv", ".mp4", ".m4v", ".mov", ".avi", ".webm", ".ts", ".m2ts"}
KEEP_LANGUAGES = {"deu", "eng"}
UNKNOWN_LANGUAGES = {"", "und", "unk", "unknown", "mis"}


def log(message):
    print(f"[clean-media-import] {message}", flush=True)


def probe(path):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_format", "-show_streams", "-show_chapters",
         "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def tags(stream):
    return {key.lower(): value for key, value in stream.get("tags", {}).items()}


def language_code(value):
    value = value.strip().lower().replace("_", "-").split("-")[0]
    if value in UNKNOWN_LANGUAGES:
        return "und"
    # "En" is also a language name in ISO 639-3. Prefer ISO codes over names
    # so the English two-letter tag cannot resolve to that unrelated language.
    code = pycountry.languages.get(**{"alpha_2" if len(value) == 2 else "alpha_3": value})
    if code is not None:
        return code.alpha_3
    try:
        return pycountry.languages.lookup(value).alpha_3
    except LookupError:
        return value


def original_language(value):
    language = language_code(value)
    if language == "und" or pycountry.languages.get(alpha_3=language) is None:
        raise ValueError("original language is missing or unknown; leaving files unchanged")
    return language


def keep_stream(stream, original):
    kind = stream["codec_type"]
    if kind == "video":
        return not any(stream.get("disposition", {}).get(flag) for flag in (
            "attached_pic", "timed_thumbnails", "still_image",
        ))
    if kind in {"audio", "subtitle"}:
        language = language_code(stream.get("mkv_language", tags(stream).get("language", "")))
        # Keep untagged tracks so missing language metadata cannot discard
        # the original audio or useful subtitles.
        return language in KEEP_LANGUAGES | {original, "und"}
    if kind == "attachment":
        mime = tags(stream).get("mimetype", "").lower()
        # ASS subtitles need their embedded fonts. Covers and other attachments
        # have no playback role and are deliberately excluded.
        return stream.get("codec_name") in {"ttf", "otf"} or mime in FONT_MIMES or mime.startswith("font/")
    return False


def matroska(path, info):
    result = subprocess.run(["mkvmerge", "-J", str(path)], check=True, capture_output=True, text=True)
    data = json.loads(result.stdout)
    # MKVToolNix track IDs and FFprobe stream indexes are different namespaces.
    # Match their ordered media tracks, never use an FFprobe index as a TID.
    media = [s for s in info["streams"] if s["codec_type"] in {"video", "audio", "subtitle"}
             and not s.get("disposition", {}).get("attached_pic")]
    tracks = data["tracks"]
    if [s["codec_type"] for s in media] != [t["type"].removesuffix("s") for t in tracks]:
        raise ValueError("FFprobe and MKVToolNix disagree on track order")
    for stream, track in zip(media, tracks):
        stream["mkv_id"] = track["id"]
        stream["mkv_uid"] = track["properties"]["uid"]
        # LanguageIETF takes precedence over Matroska's legacy language field.
        stream["mkv_language"] = track["properties"].get("language_ietf") or track["properties"].get("language", "und")
    attachments = [s for s in info["streams"] if s["codec_type"] == "attachment"
                   or s.get("disposition", {}).get("attached_pic")]
    if len(attachments) != len(data.get("attachments", [])):
        raise ValueError("FFprobe and MKVToolNix disagree on attachments")
    for stream, attachment in zip(attachments, data.get("attachments", [])):
        stream["mkv_id"] = attachment["id"]


def run_mkv(args):
    result = subprocess.run(args, capture_output=True, text=True)
    # MKVToolNix uses 1 for a completed output with warnings, 2 for failure.
    if result.returncode not in {0, 1}:
        log(result.stdout.strip() + result.stderr.strip())
        raise subprocess.CalledProcessError(result.returncode, args, result.stdout, result.stderr)
    if result.returncode == 1:
        log(result.stdout.strip() + result.stderr.strip())


def mkv_remux_args(path, output, streams):
    media = [s for s in streams if s["codec_type"] in {"video", "audio", "subtitle"}]
    args = ["mkvmerge", "-o", str(output), "--title", "", "--disable-track-statistics-tags",
            "--enable-legacy-font-mime-types",
            "--track-order", ",".join(f"0:{s['mkv_id']}" for s in media),
            "--no-global-tags", "--no-track-tags", "--no-buttons"]
    for kind, option, exclude in (("video", "video-tracks", "no-video"), ("audio", "audio-tracks", "no-audio"),
                                  ("subtitle", "subtitle-tracks", "no-subtitles"), ("attachment", "attachments", "no-attachments")):
        ids = [str(s["mkv_id"]) for s in streams if s["codec_type"] == kind]
        if ids:
            args.extend((f"--{option}", ",".join(ids)))
        else:
            args.append(f"--{exclude}")
    for stream in media:
        args.extend(("--track-name", f"{stream['mkv_id']}:"))
    return args + [str(path)]


def metadata_dirty(info):
    # Ignore muxer-generated statistics. They cannot contain release labels.
    generated = {"encoder", "creation_time", "duration", "bps", "number_of_frames", "number_of_bytes",
                 "major_brand", "minor_version", "compatible_brands", "vendor_id"}
    for item in [info.get("format", {})] + info["streams"]:
        allowed = generated | ({"filename", "mimetype"} if item.get("codec_type") == "attachment" else {"language"})
        metadata = tags(item)
        if metadata.get("handler_name") in {"VideoHandler", "SoundHandler", "SubtitleHandler"}:
            metadata.pop("handler_name")
        if any(value and key not in allowed and not key.startswith("_statistics_") for key, value in metadata.items()):
            return True
    return False


def mkv_edit(path, output, streams):
    # Work on a private clone, not the library inode. ZFS block cloning avoids
    # rewriting the whole film just to clear a few header fields.
    subprocess.run(["cp", "--reflink=auto", "--", str(path), str(output)], check=True)
    args = ["mkvpropedit", str(output), "--edit", "info", "--delete", "title", "--tags", "all:"]
    for stream in streams:
        if "mkv_uid" in stream:
            args.extend(("--edit", f"track:={stream['mkv_uid']}", "--delete", "name"))
    run_mkv(args)


def remux_args(path, output, info, streams):
    # Blu-ray remuxes can have non-monotonic inferred DTS. Let FFmpeg repair
    # timestamps while copying packets; -xerror aborts these valid imports.
    args = ["ffmpeg", "-nostdin", "-hide_banner", "-v", "error", "-y", "-i", str(path)]
    for stream in streams:
        args.extend(("-map", f"0:{stream['index']}"))
    args.extend(("-c", "copy", "-map_metadata", "-1", "-map_metadata:s", "-1", "-map_chapters", "0", "-metadata", "encoder="))
    for index, chapter in enumerate(info.get("chapters", [])):
        args.extend((f"-map_metadata:c:{index}", "-1"))
        title = tags(chapter).get("title")
        if title:
            args.extend((f"-metadata:c:{index}", f"title={title}"))
    for index, stream in enumerate(streams):
        metadata = tags(stream)
        if stream["codec_type"] == "attachment":
            for key in ("filename", "mimetype"):
                if key in metadata:
                    args.extend((f"-metadata:s:{index}", f"{key}={metadata[key]}"))
            continue
        # Players derive track labels from codec, language and dispositions.
        if path.suffix.lower() in {".mp4", ".m4v", ".mov"}:
            args.extend((f"-metadata:s:{index}", "handler_name="))
        if metadata.get("language"):
            args.extend((f"-metadata:s:{index}", f"language={metadata['language']}"))
        disposition = "+".join(key for key, value in stream.get("disposition", {}).items() if value) or "0"
        args.extend((f"-disposition:{index}", disposition))
    return args + [str(output)]


def packet_signatures(path, streams):
    args = ["ffmpeg", "-nostdin", "-v", "error", "-i", str(path)]
    for stream in streams:
        if stream["codec_type"] in {"video", "audio", "subtitle"}:
            args.extend(("-map", f"0:{stream['index']}"))
    args.extend(("-c", "copy", "-f", "streamhash", "-hash", "sha256", "-"))
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def validate(info, output_info, streams, verify_duration=True):
    output_streams = output_info["streams"]
    for key in ("codec_type", "codec_name", "width", "height", "channels", "sample_rate"):
        if [stream.get(key) for stream in streams] != [stream.get(key) for stream in output_streams]:
            raise ValueError(f"remux changed stream {key}")
    before = float(info.get("format", {}).get("duration", 0))
    after = float(output_info.get("format", {}).get("duration", 0))
    if verify_duration and before and abs(before - after) > 2:
        raise ValueError(f"remux changed duration from {before} to {after}")
    if len(info.get("chapters", [])) != len(output_info.get("chapters", [])):
        raise ValueError("remux changed the chapter count")
    for before_chapter, after_chapter in zip(info.get("chapters", []), output_info.get("chapters", [])):
        if tags(before_chapter).get("title") != tags(after_chapter).get("title"):
            raise ValueError("remux changed a chapter title")
        for key in ("start_time", "end_time"):
            if abs(float(before_chapter[key]) - float(after_chapter[key])) > 0.002:
                raise ValueError(f"remux changed chapter {key}")
    if metadata_dirty(output_info):
        raise ValueError("output still contains unwanted metadata or track titles")
    for before_stream, after_stream in zip(streams, output_streams):
        if before_stream["codec_type"] not in {"video", "audio", "subtitle"}:
            continue
        before_language = before_stream.get("mkv_language", tags(before_stream).get("language", ""))
        after_language = after_stream.get("mkv_language", tags(after_stream).get("language", ""))
        if language_code(before_language) != language_code(after_language):
            raise ValueError("remux changed a track language")
        if before_stream.get("disposition") != after_stream.get("disposition"):
            raise ValueError("remux changed track dispositions")


def identity(stat):
    return stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns


def clean(path, original, dry_run=False):
    language = original_language(original)
    path = path.resolve(strict=True)
    if path.suffix.lower() not in EXTENSIONS:
        log(f"unsupported container, skipped {path}")
        return
    with path.open("rb") as source:
        fcntl.flock(source, fcntl.LOCK_EX)
        original = os.fstat(source.fileno())
        if identity(original) != identity(path.stat()):
            log(f"another import hook already replaced {path}")
            return
        info = probe(path)
        is_mkv = path.suffix.lower() == ".mkv"
        if is_mkv:
            matroska(path, info)
        streams = [stream for stream in info["streams"] if keep_stream(stream, language)]
        if not any(stream["codec_type"] == "video" for stream in streams):
            raise ValueError(f"no video stream in {path}")
        if any(stream["codec_type"] == "audio" for stream in info["streams"]) and not any(
            stream["codec_type"] == "audio" for stream in streams
        ):
            raise ValueError(f"language filtering would remove all audio in {path}")
        removed = [s for s in info["streams"] if s not in streams]
        if not removed and not metadata_dirty(info):
            return False
        if dry_run:
            log(f"would clean {path}; remove tracks {[s['index'] for s in removed]}")
            return True
        descriptor, temporary = tempfile.mkstemp(prefix=".media-cleanup-", suffix=path.suffix, dir=path.parent)
        os.close(descriptor)
        output = Path(temporary)
        try:
            if is_mkv:
                if removed:
                    run_mkv(mkv_remux_args(path, output, streams))
                else:
                    mkv_edit(path, output, streams)
            else:
                subprocess.run(remux_args(path, output, info, streams), check=True)
            output_info = probe(output)
            if is_mkv:
                matroska(output, output_info)
            if is_mkv and removed:
                # Old MKV duration headers can be padded or reflect a removed
                # subtitle's end time. Check every retained packet instead of
                # rejecting a correct remux based on that container duration.
                if packet_signatures(path, streams) != packet_signatures(output, output_info["streams"]):
                    raise ValueError("remux changed retained packet payloads")
                validate(info, output_info, streams, verify_duration=False)
            else:
                validate(info, output_info, streams)
            if any(not keep_stream(s, language) for s in output_info["streams"]):
                raise ValueError("output still contains unwanted tracks")
            # Copy mode and ACLs, retaining the shared group even when SABnzbd
            # owned the file that Radarr/Sonarr moved into place.
            # The setgid library directory already gives the temporary file
            # its shared group. PrivateUsers exposes that unmapped GID as
            # 65534, which chown rejects even when the group would not change.
            # A privileged maintenance run can also retain the original owner;
            # import hooks cannot chown SABnzbd-owned files back to SABnzbd.
            if os.geteuid() == 0 and output.stat().st_uid != original.st_uid:
                os.chown(output, original.st_uid, original.st_gid)
            elif output.stat().st_gid != original.st_gid:
                os.chown(output, -1, original.st_gid)
            shutil.copystat(path, output)
            # Jellyfin only re-probes files whose mtime changed, so keep the
            # source's mode and ACLs but stamp the remux as freshly modified.
            os.utime(output)
            with output.open("rb") as result:
                os.fsync(result.fileno())
            if identity(original) != identity(path.stat()):
                raise ValueError(f"source changed during cleanup: {path}")
            os.replace(output, path)
            log(f"cleaned {path}")
            return True
        finally:
            output.unlink(missing_ok=True)


def event_paths(environ):
    # StringDictionary in Servarr exports lowercase names on Unix. Accept
    # mixed case too, so the same script works with manually supplied events.
    env = {key.lower(): value for key, value in environ.items()}
    app = next((app for app in ("radarr", "sonarr") if f"{app}_eventtype" in env), None)
    if app is None:
        raise ValueError("supply files or run as a Radarr/Sonarr import hook")
    event = env[f"{app}_eventtype"].lower()
    if event == "test":
        log("connection test passed")
        return []
    if event != "download":
        return []
    singular = "radarr_moviefile_path" if app == "radarr" else "sonarr_episodefile_path"
    paths = env.get(singular) or env.get("sonarr_episodefile_paths", "")
    if not paths:
        raise ValueError(f"{app} import event has no file paths")
    return [Path(paths)] if singular in env and env[singular] else [Path(path) for path in paths.split("|") if path]


def api_request(api_url, env, app, endpoint, data=None):
    request = Request(
        api_url.rstrip("/") + "/" + endpoint,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"X-Api-Key": env[f"{app}__auth__apikey"], "Content-Type": "application/json"},
    )
    with urlopen(request, timeout=30) as response:
        body = response.read()
        return json.loads(body) if body else None


def library_files(api_url, env, app, roots):
    resource = "series" if app == "sonarr" else "movie"
    titles = api_request(api_url, env, app, resource)
    roots = [root.resolve(strict=True) for root in roots]
    matched = {}
    for title in titles:
        directory = Path(title["path"]).resolve()
        if not any(directory.is_relative_to(root) for root in roots):
            continue
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix.lower() in EXTENSIONS and not path.name.startswith(".media-cleanup-"):
                resolved = path.resolve(strict=True)
                if not any(resolved.is_relative_to(root) for root in roots):
                    raise ValueError(f"library file points outside requested roots: {path}")
                matched[resolved] = title
    # A missing API match must not silently leave a title out of the audit.
    for root in roots:
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in EXTENSIONS and not path.name.startswith(".media-cleanup-"):
                if path.resolve(strict=True) not in matched:
                    raise ValueError(f"no {app} original-language metadata for {path}")
    return matched


def clean_library(api_url, env, app, roots, dry_run):
    files = library_files(api_url, env, app, roots)
    failures, changed, refresh = [], 0, set()
    for path, title in sorted(files.items()):
        try:
            original = original_language(title.get("originalLanguage", {}).get("name", ""))
            if clean(path, original, dry_run=dry_run):
                changed += 1
                refresh.add(title["id"])
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            log(f"cleanup failed for {path}: {error}")
            failures.append(path)
    if not dry_run:
        resource = "series" if app == "sonarr" else "movie"
        for resource_id in sorted(refresh):
            rescan(api_url, env | {f"{app}_{resource}_id": str(resource_id)}, app)
    log(f"{app}: checked {len(files)} files, {'would change' if dry_run else 'changed'} {changed}, failed {len(failures)}")
    return bool(failures)


def rescan(api_url, env, app):
    resource = "series" if app == "sonarr" else "movie"
    resource_id = int(env[f"{app}_{resource}_id"])
    if resource_id <= 0:
        raise ValueError("rescan requires a positive series or movie ID")
    command = {"name": "RescanSeries" if app == "sonarr" else "RescanMovie", f"{resource}Id": resource_id}
    # Only queue the command. Waiting for it inside an import notification
    # can block the import that the rescan needs to finish first.
    api_request(api_url, env, app, "command", command)
    log(f"queued {command['name']} for {resource_id}")


def main(argv=None, environ=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", type=Path)
    parser.add_argument("--original-language", help="original language for manually supplied files")
    parser.add_argument("--api-url", help="Servarr API URL, including /api/v3")
    parser.add_argument("--app", choices=("sonarr", "radarr"), help="app owning --library-root")
    parser.add_argument("--library-root", action="append", type=Path, default=[],
                        help="audit/repair this library using original languages from the app API; repeatable")
    parser.add_argument("--dry-run", action="store_true", help="report changes without writing files")
    args = parser.parse_args(argv)
    env = {key.lower(): value for key, value in (os.environ if environ is None else environ).items()}
    if args.library_root:
        if args.files or args.original_language or not args.app or not args.api_url:
            parser.error("--library-root requires --app and --api-url, without files or --original-language")
        return clean_library(args.api_url, env, args.app, args.library_root, args.dry_run)
    app = next((app for app in ("radarr", "sonarr") if f"{app}_eventtype" in env), None)
    event = env.get(f"{app}_eventtype", "").lower()
    # Sonarr's batch completion event refreshes media info once all per-file
    # cleanup has finished, without scanning while other episodes are moving.
    if not args.files and app == "sonarr" and event == "importcomplete":
        if args.dry_run:
            return False
        if not args.api_url:
            parser.error("--api-url is required to refresh imported media info")
        rescan(args.api_url, env, app)
        return False
    paths = args.files or event_paths(env)
    if not paths:
        return False
    resource = "series" if app == "sonarr" else "movie"
    original = original_language(args.original_language or env.get(f"{app}_{resource}_originallanguage", ""))
    if not args.files and not args.api_url:
        parser.error("--api-url is required to refresh imported media info")
    failures = []
    for path in dict.fromkeys(paths):
        try:
            if args.dry_run:
                clean(path, original, dry_run=True)
            else:
                clean(path, original)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            log(f"cleanup failed for {path}: {error}")
            failures.append(path)
    if not args.files and app == "radarr" and not args.dry_run:
        rescan(args.api_url, env, app)
    return bool(failures)


def terminate(signum, _frame):
    # A service restart must unwind clean()'s finally block, not abandon a
    # partially written remux in a directory scanned by media servers.
    raise SystemExit(128 + signum)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, terminate)
    raise SystemExit(main())

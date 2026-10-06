"""Keep Japanese, German, English and untagged tracks, then clean metadata."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


FONT_MIMES = {
    "application/x-truetype-font", "application/x-font-ttf",
    "application/x-font", "application/font-sfnt", "application/vnd.ms-opentype",
    "application/x-font-opentype", "application/font-woff",
}
EXTENSIONS = {".mkv", ".mp4", ".m4v", ".mov", ".avi", ".webm", ".ts", ".m2ts"}
KEEP_LANGUAGES = {"ja", "jpn", "de", "deu", "ger", "en", "eng"}
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


def keep_stream(stream):
    kind = stream["codec_type"]
    if kind == "video":
        return not any(stream.get("disposition", {}).get(flag) for flag in (
            "attached_pic", "timed_thumbnails", "still_image",
        ))
    if kind in {"audio", "subtitle"}:
        language = tags(stream).get("language", "").strip().lower().replace("_", "-").split("-")[0]
        # Keep untagged tracks so missing language metadata cannot discard
        # the original audio or useful subtitles.
        return language in KEEP_LANGUAGES or language in UNKNOWN_LANGUAGES
    if kind == "attachment":
        mime = tags(stream).get("mimetype", "").lower()
        # ASS subtitles need their embedded fonts. Covers and other attachments
        # have no playback role and are deliberately excluded.
        return stream.get("codec_name") in {"ttf", "otf"} or mime in FONT_MIMES or mime.startswith("font/")
    return False


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


def validate(info, output_info, streams):
    output_streams = output_info["streams"]
    for key in ("codec_type", "codec_name", "width", "height", "channels", "sample_rate"):
        if [stream.get(key) for stream in streams] != [stream.get(key) for stream in output_streams]:
            raise ValueError(f"remux changed stream {key}")
    before = float(info.get("format", {}).get("duration", 0))
    after = float(output_info.get("format", {}).get("duration", 0))
    if before and abs(before - after) > 2:
        raise ValueError(f"remux changed duration from {before} to {after}")
    if len(info.get("chapters", [])) != len(output_info.get("chapters", [])):
        raise ValueError("remux changed the chapter count")


def identity(stat):
    return stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns


def clean(path):
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
        streams = [stream for stream in info["streams"] if keep_stream(stream)]
        if not any(stream["codec_type"] == "video" for stream in streams):
            raise ValueError(f"no video stream in {path}")
        descriptor, temporary = tempfile.mkstemp(prefix=".media-cleanup-", suffix=path.suffix, dir=path.parent)
        os.close(descriptor)
        output = Path(temporary)
        try:
            subprocess.run(remux_args(path, output, info, streams), check=True)
            validate(info, probe(output), streams)
            # Copy mode, timestamps and ACLs, retaining the shared group even
            # when SABnzbd owned the file that Radarr/Sonarr moved into place.
            # The setgid library directory already gives the temporary file
            # its shared group. PrivateUsers exposes that unmapped GID as
            # 65534, which chown rejects even when the group would not change.
            if output.stat().st_gid != original.st_gid:
                os.chown(output, -1, original.st_gid)
            shutil.copystat(path, output)
            with output.open("rb") as result:
                os.fsync(result.fileno())
            if identity(original) != identity(path.stat()):
                raise ValueError(f"source changed during cleanup: {path}")
            os.replace(output, path)
            log(f"cleaned {path}")
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", type=Path)
    args = parser.parse_args()
    failures = []
    for path in dict.fromkeys(args.files or event_paths(os.environ)):
        try:
            clean(path)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            log(f"cleanup failed for {path}: {error}")
            failures.append(path)
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())

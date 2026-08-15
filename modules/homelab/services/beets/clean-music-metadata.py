#!/usr/bin/env python3
"""Remove download provenance from audio metadata before a Beets import."""

import argparse
import os
import sys
from pathlib import Path

import mutagen
from mutagen.id3 import ID3


PREFIX = "[clean-music-metadata]"
AUDIO_EXTENSIONS = {
    ".aac",
    ".aif",
    ".aiff",
    ".ape",
    ".asf",
    ".dff",
    ".dsf",
    ".flac",
    ".m4a",
    ".m4b",
    ".mp3",
    ".mp4",
    ".mpc",
    ".oga",
    ".ogg",
    ".opus",
    ".spx",
    ".tta",
    ".wav",
    ".wma",
    ".wv",
}

# These fields carry download-site advertising or tooling provenance rather
# than release identity. Keep artist, album, title, numbering, MusicBrainz IDs,
# artwork, lyrics, and other tags Beets can use to identify the release.
JUNK_FIELD_NAMES = {
    "comment",
    "comments",
    "contentgroup",
    "contentgroupdescription",
    "description",
    "downloadedfrom",
    "downloadurl",
    "encodedby",
    "encoder",
    "encoderoptions",
    "encodersettings",
    "encoding",
    "encodingsettings",
    "encodingtool",
    "fileurl",
    "grouping",
    "licenseurl",
    "purchaseurl",
    "ripper",
    "source",
    "sourceurl",
    "uri",
    "url",
    "website",
    "www",
}


def log(message):
    print(f"{PREFIX} {message}", flush=True)


def normalized(value):
    return "".join(character for character in value.lower() if character.isalnum())


def is_junk_field(name):
    """Recognize provenance fields without matching identity fields by accident."""
    field = normalized(name)
    return field in JUNK_FIELD_NAMES or field.endswith(("url", "uri", "website"))


def junk_tag_keys(tags):
    """Return format-specific tag keys that should be removed."""
    keys = []
    is_id3 = isinstance(tags, ID3)
    for key in tags.keys():
        name = str(key)
        upper_name = name.upper()

        # ID3 comments, URL link frames, and encoder/grouping frames. ID3 keys
        # can include a description suffix, e.g. COMM:description:eng.
        if is_id3 and (
            upper_name.startswith(("COMM", "W"))
            or upper_name in {"GRP1", "TENC", "TIT1", "TSSE"}
        ):
            keys.append(key)
            continue

        # MP4 free-form atoms use ----:mean:name; inspect only their final name
        # so the com.apple.iTunes namespace itself does not look suspicious.
        # ASF keys use a similar WM/EncodedBy namespace.
        field_name = name.rsplit(":", 1)[-1].rsplit("/", 1)[-1]
        if is_junk_field(field_name):
            keys.append(key)
            continue

        # Native MP4 atoms do not have descriptive names.
        if name in {
            "\N{COPYRIGHT SIGN}cmt",
            "\N{COPYRIGHT SIGN}grp",
            "\N{COPYRIGHT SIGN}too",
            "desc",
            "ldes",
            "purl",
        }:
            keys.append(key)

    return keys


def iter_audio_files(paths):
    seen = set()
    for argument in paths:
        path = Path(argument)
        if path.is_dir():
            candidates = (candidate for candidate in path.rglob("*") if candidate.is_file())
        else:
            candidates = (path,)

        for candidate in candidates:
            if candidate.suffix.lower() not in AUDIO_EXTENSIONS:
                continue
            identity = os.path.realpath(candidate)
            if identity in seen:
                continue
            seen.add(identity)
            yield candidate


def process(path):
    try:
        original_stat = path.stat()
    except OSError as error:
        log(f"could not stat {path}: {error}")
        return False

    try:
        audio = mutagen.File(path, easy=False)
    except (mutagen.MutagenError, OSError) as error:
        log(f"could not read {path}: {error}")
        return False

    if audio is None:
        log(f"unsupported audio file, refusing import: {path}")
        return False
    if audio.tags is None:
        log(f"no metadata to clean in {path}")
        return True

    keys = junk_tag_keys(audio.tags)
    if not keys:
        log(f"nothing to strip in {path}")
        return True

    for key in keys:
        del audio.tags[key]

    try:
        audio.save()
        # Content changes should not make an already-settled download look new
        # to the Beets worker's timestamp-based candidate selection.
        os.utime(path, ns=(original_stat.st_atime_ns, original_stat.st_mtime_ns))
    except (mutagen.MutagenError, OSError) as error:
        log(f"could not save {path}: {error}")
        return False

    log(f"stripped {len(keys)} provenance tag(s) from {path}")
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", help="audio files or directories to clean")
    arguments = parser.parse_args()

    files = list(iter_audio_files(arguments.paths))
    if not files:
        log("no audio files found")
        return 0

    succeeded = True
    for path in files:
        succeeded = process(path) and succeeded
    return 0 if succeeded else 1


if __name__ == "__main__":
    sys.exit(main())

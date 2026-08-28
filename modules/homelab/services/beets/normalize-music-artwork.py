#!/usr/bin/env python3
"""Reject non-square Beets artwork and preserve valid embedded fallback art."""

import argparse
import io
import tempfile
from pathlib import Path

import mediafile
from PIL import Image, UnidentifiedImageError

from beets import config
from beets.library import Library
from beets.util import bytestring_path, syspath


PREFIX = "[normalize-music-artwork]"


def log(message):
    print(f"{PREFIX} {message}", flush=True)


def image_is_valid(source, max_deviation):
    try:
        with Image.open(source) as image:
            width, height = image.size
            image.verify()
    except (OSError, UnidentifiedImageError):
        return False

    return min(width, height) > 0 and abs(width - height) / max(width, height) <= max_deviation


def embedded_art(album, max_deviation):
    for item in album.items():
        try:
            data = mediafile.MediaFile(syspath(item.path)).art
        except mediafile.UnreadableFileError as error:
            log(f"could not read {syspath(item.path)}: {error}")
            continue

        if data and image_is_valid(io.BytesIO(data), max_deviation):
            return data

    return None


def clear_associated_art(album, music_root):
    path = Path(syspath(album.artpath))
    album.artpath = None
    album["art_source"] = ""
    album.store()

    try:
        resolved = path.resolve()
        if resolved.is_relative_to(music_root) and resolved.is_file():
            resolved.unlink()
    except OSError as error:
        raise RuntimeError(f"could not remove rejected art {path}: {error}") from error


def associate_embedded_fallback(album, data):
    extension = mediafile.image_extension(data)
    if not extension:
        return False

    album_dir = Path(syspath(album.path))
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            dir=album_dir,
            prefix=".beets-embedded-art-",
            suffix=f".{extension}",
            delete=False,
        ) as output:
            output.write(data)
            temporary = Path(output.name)

        album.set_art(bytestring_path(temporary), copy=False)
        album["art_source"] = "filesystem"
        album.store()
        return True
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, help="generated Beets configuration")
    parser.add_argument(
        "--max-deviation",
        type=float,
        default=0.01,
        help="maximum width/height deviation as a fraction of the longer edge",
    )
    arguments = parser.parse_args()

    config.read()
    config.set_file(arguments.config)
    music_directory = config["directory"].as_filename()
    library = Library(config["library"].as_filename(), music_directory)
    music_root = Path(music_directory).resolve()

    for album in library.albums():
        if album.artpath:
            art_path = Path(syspath(album.artpath))
            if art_path.is_file() and image_is_valid(art_path, arguments.max_deviation):
                continue

            log(f"rejecting associated art for {album}: {art_path}")
            clear_associated_art(album, music_root)

        fallback = embedded_art(album, arguments.max_deviation)
        if fallback and associate_embedded_fallback(album, fallback):
            log(f"preserved square embedded fallback for {album}")

    library._close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

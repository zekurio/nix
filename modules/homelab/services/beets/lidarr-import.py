"""Enrich one Lidarr import in place with an isolated beets database."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def album_directory(environ, music_dir):
    tracks = [Path(path).resolve(strict=True) for path in environ["lidarr_addedtrackpaths"].split("|") if path]
    if not tracks:
        raise ValueError("Lidarr supplied no imported tracks")
    root = Path(music_dir).resolve(strict=True)
    artist = Path(environ["lidarr_artist_path"]).resolve(strict=True)
    for track in tracks:
        if not track.is_file() or not track.is_relative_to(root) or not track.is_relative_to(artist):
            raise ValueError("Imported track is outside the artist's music library")
    # Take the common parent so a multi-disc release is tagged as one album.
    album = Path(os.path.commonpath([str(track.parent) for track in tracks]))
    if album in (root, artist) or not album.is_relative_to(artist):
        raise ValueError("Refusing to tag an entire music or artist directory")
    return album


def vorbis_comment_blocks(path):
    """Count VORBIS_COMMENT metadata blocks in a FLAC file."""
    count = 0
    with open(path, "rb") as stream:
        if stream.read(4) != b"fLaC":
            return 0
        while True:
            header = stream.read(4)
            if len(header) < 4:
                return count
            count += header[0] & 0x7F == 4
            if header[0] & 0x80:
                return count
            stream.seek(int.from_bytes(header[1:], "big"), os.SEEK_CUR)


def merge_duplicate_comments(tracks, ffmpeg):
    """Some releases carry two Vorbis comment blocks; taggers read only the first.

    FFmpeg merges them, so remux affected files in place with streams copied.
    """
    for track in tracks:
        if track.suffix.lower() != ".flac" or vorbis_comment_blocks(track) < 2:
            continue
        fixed = track.with_name(f".{track.name}.fixed.flac")
        try:
            subprocess.run([
                ffmpeg, "-v", "error", "-y", "-i", str(track), "-map", "0",
                "-c", "copy", "-map_metadata", "0", str(fixed),
            ], check=True)
            shutil.copymode(track, fixed)
            fixed.replace(track)
        finally:
            fixed.unlink(missing_ok=True)


def main():
    # Lidarr's Test event has no paths. Other notification types are unrelated.
    if os.environ.get("lidarr_eventtype") != "AlbumDownload":
        return
    parser = argparse.ArgumentParser()
    parser.add_argument("--beet", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--music-dir", required=True)
    args = parser.parse_args()
    album = album_directory(os.environ, args.music_dir)
    merge_duplicate_comments(sorted(album.rglob("*")), shutil.which("ffmpeg") or "ffmpeg")
    with tempfile.TemporaryDirectory(prefix="lidarr-beets-") as state:
        # Never add Lidarr's files to the persistent Copyparty beets library.
        environment = os.environ | {
            "BEETSDIR": state, "HOME": state, "XDG_CACHE_HOME": f"{state}/cache",
        }
        subprocess.run([
            args.beet, "--config", args.config, "--library", f"{state}/library.db",
            "import", "--quiet", "--noincremental", str(album),
        ], check=True, env=environment)


if __name__ == "__main__":
    main()

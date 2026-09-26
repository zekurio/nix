"""Enrich one Lidarr import in place with an isolated beets database."""

import argparse
import os
from pathlib import Path
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

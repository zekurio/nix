#!/usr/bin/env python3
"""Strip embedded track names from MKV files imported by Sonarr or Radarr."""

import json
import os
import subprocess
import sys


PREFIX = "[clean-track-names]"
TRACK_TYPES = {"video", "audio", "subtitles"}


def log(message):
    print(f"{PREFIX} {message}", flush=True)


def get_target_files():
    """Return MKV paths exposed by Sonarr and Radarr custom-script events."""
    files = []
    for variable in (
        "radarr_moviefile_path",
        "radarr_moviefile_paths",
        "sonarr_episodefile_path",
        "sonarr_episodefile_paths",
    ):
        value = os.environ.get(variable)
        if value:
            files.extend(path for path in value.split("|") if path)

    # Preserve event order while avoiding duplicate work if an event exposes the
    # same path through both a singular and a plural environment variable.
    return list(dict.fromkeys(path for path in files if path.lower().endswith(".mkv")))


def process(path):
    if not os.path.exists(path):
        log(f"not found, skipping: {path}")
        return True

    try:
        result = subprocess.run(
            ["mkvmerge", "-J", path],
            capture_output=True,
            check=True,
            text=True,
        )
        info = json.loads(result.stdout)
    except (json.JSONDecodeError, subprocess.CalledProcessError) as error:
        detail = getattr(error, "stderr", None) or str(error)
        log(f"mkvmerge failed on {path}: {detail.strip()}")
        return False

    edits = []
    for position, track in enumerate(info.get("tracks", []), start=1):
        if track.get("type") not in TRACK_TYPES:
            continue
        if not track.get("properties", {}).get("track_name"):
            continue
        # Numeric selectors address the track's position in mkvmerge's identify
        # output. Unlike vN/aN/sN, this remains correct when track types are mixed.
        edits.append(f"track:{position}")

    if not edits:
        log(f"nothing to strip in {path}")
        return True

    command = ["mkvpropedit", path]
    for selector in edits:
        command.extend(["--edit", selector, "--delete", "name"])

    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode == 0:
        log(f"stripped {len(edits)} track name(s) in {path}")
        return True

    log(f"mkvpropedit failed on {path}: {result.stderr.strip()}")
    return False


def main():
    files = get_target_files()
    if not files:
        log("no MKV file paths in environment; exiting")
        return 0

    succeeded = True
    for path in files:
        log(f"processing {path}")
        succeeded = process(path) and succeeded
    return 0 if succeeded else 1


if __name__ == "__main__":
    sys.exit(main())

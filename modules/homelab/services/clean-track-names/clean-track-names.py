"""Import media for Sonarr/Radarr and strip MKV track names safely."""

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile

PREFIX = "[clean-track-names]"
TRACK_TYPES = {"video", "audio", "subtitles"}
TRANSFER_MODE_VARIABLES = ("Sonarr_TransferMode", "Radarr_TransferMode")
TRANSFER_MODES = {"copy", "hardlinkorcopy", "move"}


class ImportFailure(Exception):
    """An error that should make Sonarr/Radarr reject the import."""


def log(message):
    print(f"{PREFIX} {message}", flush=True)


def command_error(command, error):
    detail = error.stderr or error.stdout or str(error)
    return ImportFailure(f"{command} failed: {detail.strip()}")


def get_transfer_mode():
    """Return the transfer mode supplied by the active Arr application."""
    modes = {
        value.casefold()
        for variable in TRANSFER_MODE_VARIABLES
        if (value := os.environ.get(variable))
    }
    if len(modes) != 1:
        names = " or ".join(TRANSFER_MODE_VARIABLES)
        raise ImportFailure(f"expected exactly one transfer mode in {names}")

    mode = modes.pop()
    if mode not in TRANSFER_MODES:
        raise ImportFailure(f"unsupported transfer mode: {mode}")
    return mode


def named_track_selectors(path):
    """Return mkvpropedit selectors for named video, audio, and subtitle tracks."""
    try:
        result = subprocess.run(
            ["mkvmerge", "-J", path],
            capture_output=True,
            check=True,
            text=True,
        )
        info = json.loads(result.stdout)
    except subprocess.CalledProcessError as error:
        raise command_error("mkvmerge", error) from error
    except json.JSONDecodeError as error:
        raise ImportFailure(f"mkvmerge returned invalid JSON: {error}") from error
    except OSError as error:
        raise ImportFailure(f"could not execute mkvmerge: {error}") from error

    selectors = []
    for position, track in enumerate(info.get("tracks", []), start=1):
        if track.get("type") not in TRACK_TYPES:
            continue
        if not track.get("properties", {}).get("track_name"):
            continue
        # Numeric selectors address the track's position in mkvmerge's identify
        # output. Unlike vN/aN/sN, this remains correct when track types are mixed.
        selectors.append(f"track:{position}")
    return selectors


def strip_track_names(path, selectors):
    command = ["mkvpropedit", path]
    for selector in selectors:
        command.extend(["--edit", selector, "--delete", "name"])

    try:
        subprocess.run(command, capture_output=True, check=True, text=True)
    except subprocess.CalledProcessError as error:
        raise command_error("mkvpropedit", error) from error
    except OSError as error:
        raise ImportFailure(f"could not execute mkvpropedit: {error}") from error


def copy_to_temp(source, destination):
    """Copy beside the destination so publication can be atomic."""
    destination_directory = os.path.dirname(destination)
    descriptor, temporary_path = tempfile.mkstemp(
        dir=destination_directory,
        prefix=f".{os.path.basename(destination)}.clean-",
        suffix=os.path.splitext(destination)[1],
    )
    os.close(descriptor)

    try:
        shutil.copy2(source, temporary_path)
        if os.path.getsize(temporary_path) != os.path.getsize(source):
            raise ImportFailure("temporary copy has the wrong size")
    except (ImportFailure, OSError, shutil.Error):
        try:
            os.unlink(temporary_path)
        except FileNotFoundError:
            pass
        raise

    return temporary_path


def publish_temp(temporary_path, destination):
    """Publish a completed temporary file without replacing an existing file."""
    try:
        os.link(temporary_path, destination)
    except FileExistsError as error:
        raise ImportFailure(f"destination already exists: {destination}") from error
    except OSError as error:
        raise ImportFailure(f"could not publish destination: {error}") from error

    os.unlink(temporary_path)


def copy_atomic(source, destination):
    temporary_path = copy_to_temp(source, destination)
    try:
        publish_temp(temporary_path, destination)
    finally:
        try:
            os.unlink(temporary_path)
        except FileNotFoundError:
            pass


def hardlink_or_copy(source, destination):
    try:
        os.link(source, destination)
        return "hardlinked"
    except FileExistsError as error:
        raise ImportFailure(f"destination already exists: {destination}") from error
    except OSError as error:
        if os.path.exists(destination):
            raise ImportFailure(f"destination already exists: {destination}") from error
        log(f"hard link unavailable ({error}); falling back to a copy")
        copy_atomic(source, destination)
        return "copied"


def remove_source_or_rollback(source, destination):
    try:
        os.unlink(source)
    except OSError as error:
        try:
            os.unlink(destination)
        except OSError as rollback_error:
            raise ImportFailure(
                f"could not remove source ({error}) or roll back destination "
                f"({rollback_error})"
            ) from error
        raise ImportFailure(f"could not remove source: {error}") from error


def transfer_unmodified(source, destination, mode):
    if mode == "copy":
        copy_atomic(source, destination)
        return "copied"

    action = hardlink_or_copy(source, destination)
    if mode == "move":
        remove_source_or_rollback(source, destination)
        return "moved"
    return action


def import_file(source, destination, mode):
    if not os.path.isfile(source):
        raise ImportFailure(f"source is not a regular file: {source}")
    if os.path.realpath(source) == os.path.realpath(destination):
        raise ImportFailure("source and destination are the same path")
    if os.path.exists(destination):
        raise ImportFailure(f"destination already exists: {destination}")
    if not os.path.isdir(os.path.dirname(destination)):
        raise ImportFailure(f"destination directory does not exist: {destination}")

    if not source.lower().endswith(".mkv"):
        action = transfer_unmodified(source, destination, mode)
        log(f"{action} non-MKV file without changes: {destination}")
        return

    selectors = named_track_selectors(source)
    if not selectors:
        action = transfer_unmodified(source, destination, mode)
        log(f"{action} MKV with no track names: {destination}")
        return

    # Editing a hard link would also mutate the download client's source file.
    # Always clean a private copy, publish it only after verification, and remove
    # the source afterward only when Arr requested Move semantics.
    temporary_path = copy_to_temp(source, destination)
    try:
        original_mode = stat.S_IMODE(os.stat(temporary_path).st_mode)
        os.chmod(temporary_path, original_mode | stat.S_IWUSR)
        strip_track_names(temporary_path, selectors)
        remaining = named_track_selectors(temporary_path)
        if remaining:
            raise ImportFailure(
                f"verification found {len(remaining)} track name(s) after cleanup"
            )
        os.chmod(temporary_path, original_mode)
        publish_temp(temporary_path, destination)
    finally:
        try:
            os.unlink(temporary_path)
        except FileNotFoundError:
            pass

    if mode == "move":
        remove_source_or_rollback(source, destination)
        action = "moved"
    else:
        action = "copied"
    log(f"{action} MKV and stripped {len(selectors)} track name(s): {destination}")


def main():
    if len(sys.argv) != 3:
        log("expected source and destination path arguments")
        return 1

    source, destination = sys.argv[1:]
    try:
        mode = get_transfer_mode()
        import_file(source, destination, mode)
    except (ImportFailure, OSError) as error:
        log(f"import failed: {error}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

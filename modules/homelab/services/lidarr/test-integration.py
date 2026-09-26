"""Exercise provisioning against the pinned Lidarr and plugin in temporary state."""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import secrets
import socket
import sqlite3
import subprocess
import tempfile
import time
from types import SimpleNamespace
from urllib.error import URLError


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lidarr", required=True)
    parser.add_argument("--plugin", required=True)
    parser.add_argument("--configure", required=True)
    parser.add_argument("--script", required=True)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("configure", args.configure)
    configure = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(configure)

    with tempfile.TemporaryDirectory() as temporary:
        state = Path(temporary)
        data = state / "data"
        plugin = data / "plugins/allquiet-hub/Lidarr.Plugin.Slskd"
        plugin.parent.mkdir(parents=True)
        plugin.symlink_to(args.plugin, target_is_directory=True)
        music = state / "music"
        music.mkdir()
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        environment = os.environ | {
            "HOME": temporary,
            "LIDARR__SERVER__PORT": str(port),
            "LIDARR__SERVER__BINDADDRESS": "127.0.0.1",
            "LIDARR__SERVER__URLBASE": "/lidarr",
            "LIDARR__AUTH__APIKEY": secrets.token_hex(16),
            "LIDARR__AUTH__METHOD": "Forms",
            "LIDARR__UPDATE__MECHANISM": "external",
            "LIDARR__UPDATE__AUTOMATICALLY": "false",
            "LIDARR__LOG__ANALYTICSENABLED": "false",
        }
        api = configure.Lidarr(
            f"http://127.0.0.1:{port}/lidarr", environment["LIDARR__AUTH__APIKEY"]
        )
        settings = SimpleNamespace(
            music_dir=str(music), beets_script=args.script,
            slskd_url="http://127.0.0.1:15030/slskd",
            slskd_external_url="https://admin.example.org/slskd/",
        )
        with (state / "lidarr.log").open("w+") as log:
            process = subprocess.Popen(
                [args.lidarr, "-nobrowser", f"-data={data}"],
                env=environment, stdout=log, stderr=subprocess.STDOUT,
            )
            try:
                deadline = time.monotonic() + 90
                while True:
                    if process.poll() is not None:
                        raise RuntimeError(f"Lidarr exited with {process.returncode}")
                    try:
                        api.request("system/status")
                        break
                    except (URLError, TimeoutError):
                        if time.monotonic() >= deadline:
                            raise
                        time.sleep(1)
                assert api.request("system/status")["version"] == "3.1.6.5078"
                naming_before = api.request("config/naming")
                assert not naming_before["renameTracks"]
                configure.configure(api, settings, "first-test-api-key-1234567890")
                before = {endpoint: api.request(endpoint) for endpoint in (
                    "indexer", "downloadclient", "notification", "rootfolder"
                )}
                configure.configure(api, settings, "first-test-api-key-1234567890")
                for endpoint, resources in before.items():
                    # Free space can change while unrelated builds run.
                    stable = lambda items: [
                        {key: value for key, value in item.items() if key != "freeSpace"}
                        for item in items
                    ]
                    assert stable(api.request(endpoint)) == stable(resources), endpoint
                    assert len(resources) == 1, endpoint
                assert api.request("config/metadataprovider")["writeAudioTags"] == "no"
                assert api.request("config/mediamanagement")["watchLibraryForChanges"]
                naming_after = api.request("config/naming")
                assert naming_after["renameTracks"]
                for field in ("standardTrackFormat", "multiDiscTrackFormat", "artistFolderFormat"):
                    assert naming_after[field] == naming_before[field]
                client = before["downloadclient"][0]
                fields = {field["name"]: field.get("value") for field in client["fields"]}
                assert client["enable"] and client["removeCompletedDownloads"]
                assert fields["urlBase"] == "/slskd"
                notification = before["notification"][0]
                assert notification["onReleaseImport"] and notification["onUpgrade"]
                assert not notification["onTrackRetag"]

                # Preserve choices made in the UI when a secret rotates.
                indexer = before["indexer"][0]
                for field in indexer["fields"]:
                    if field["name"] == "minimumPeerUploadSpeed":
                        field["value"] = 1.25
                api.request(f"indexer/{indexer['id']}?forceSave=true", indexer, "PUT")
                configure.configure(api, settings, "rotated-test-api-key-1234567890")
                for endpoint in ("indexer", "downloadclient"):
                    resource = api.request(endpoint)[0]
                    fields = {field["name"]: field.get("value") for field in resource["fields"]}
                    # Lidarr masks API keys in responses; verify the saved
                    # value in this disposable database instead.
                    table = "Indexers" if endpoint == "indexer" else "DownloadClients"
                    with sqlite3.connect(data / "lidarr.db") as database:
                        saved = database.execute(
                            f'SELECT "Settings" FROM "{table}" WHERE "Id" = ?',
                            (resource["id"],),
                        ).fetchone()[0]
                    assert json.loads(saved)["apiKey"] == "rotated-test-api-key-1234567890"
                    if endpoint == "indexer":
                        assert fields["minimumPeerUploadSpeed"] == 1.25
                    assert resource["id"] == before[endpoint][0]["id"]
                print("Pinned Lidarr/plugin startup, API provisioning, repeat runs and secret rotation passed.")
            except Exception:
                log.flush()
                log.seek(0)
                print("".join(log.readlines()[-100:]))
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    main()

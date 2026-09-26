"""Provision the managed Lidarr integrations without replacing UI preferences."""

import argparse
import copy
import json
import os
import time
from urllib.error import URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


class Lidarr:
    def __init__(self, url, api_key):
        self.url = url.rstrip("/") + "/api/v1/"
        self.api_key = api_key

    def request(self, path, data=None, method=None):
        request = Request(
            self.url + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={"X-Api-Key": self.api_key, "Content-Type": "application/json"},
            method=method,
        )
        with urlopen(request, timeout=30) as response:
            body = response.read()
            return json.loads(body) if body else None

    def wait(self):
        deadline = time.monotonic() + 90
        while True:
            try:
                self.request("system/status")
                return
            except (URLError, TimeoutError):
                if time.monotonic() >= deadline:
                    raise
                time.sleep(1)

    def settings(self, endpoint, **values):
        current = self.request(endpoint)
        if any(current.get(key) != value for key, value in values.items()):
            self.request(endpoint, current | values, "PUT")

    def provider(self, endpoint, name, implementation, fields, **values):
        current = next(
            (item for item in self.request(endpoint) if item["name"] == name), None
        )
        if current is not None and current["implementation"] != implementation:
            raise ValueError(f"{name} already exists with another implementation")
        if current is None:
            current = next(
                item for item in self.request(endpoint + "/schema")
                if item["implementation"] == implementation
            )
        desired = copy.deepcopy(current)
        desired.update(name=name, **values)
        available = {field["name"]: field for field in desired["fields"]}
        for key, value in fields.items():
            available[key]["value"] = value
        if not current.get("id"):
            # Creating an enabled provider tests its remote endpoint even with
            # forceSave. Create it disabled, then enable it without requiring
            # Soulseek connectivity during every system activation.
            disabled = copy.deepcopy(desired)
            for key in disabled:
                if key == "enable" or key.startswith("enable") or key.startswith("on"):
                    if isinstance(disabled[key], bool):
                        disabled[key] = False
            disabled.pop("id", None)
            created = self.request(endpoint + "?forceSave=true", disabled, "POST")
            desired["id"] = created["id"]
        if desired != current:
            self.request(
                f"{endpoint}/{desired['id']}?forceSave=true", desired, "PUT"
            )


def configure(api, args, slskd_key):
    # Beets owns tags; Lidarr owns downloads and paths. Watch for Copyparty's
    # separate beets importer adding files to the same music root.
    api.settings("config/metadataprovider", writeAudioTags="no")
    api.settings("config/mediamanagement", watchLibraryForChanges=True)
    api.provider(
        "notification", "Beets tag enrichment", "CustomScript",
        {"path": args.beets_script}, onReleaseImport=True, onUpgrade=True,
    )

    slskd = urlsplit(args.slskd_url)
    api.provider(
        "downloadclient", "Slskd", "Slskd",
        {
            "host": slskd.hostname,
            "port": slskd.port or (443 if slskd.scheme == "https" else 80),
            "urlBase": slskd.path.rstrip("/"),
            "useSsl": slskd.scheme == "https",
            "apiKey": slskd_key,
            "repairConfiguration": False,
        },
        enable=True, removeCompletedDownloads=True,
    )
    api.provider(
        "indexer", "Slskd", "Slskd",
        {
            "baseUrl": args.slskd_url.rstrip("/") + "/",
            "externalUrl": args.slskd_external_url,
            "apiKey": slskd_key,
        },
        enableRss=False, enableAutomaticSearch=True, enableInteractiveSearch=True,
    )

    if not any(root["path"] == args.music_dir for root in api.request("rootfolder")):
        api.request("rootfolder", {
            "name": "Music",
            "path": args.music_dir,
            "defaultQualityProfileId": api.request("qualityprofile")[0]["id"],
            "defaultMetadataProfileId": api.request("metadataprofile")[0]["id"],
            "defaultMonitorOption": "none",
            "defaultNewItemMonitorOption": "none",
            "defaultTags": [],
        }, "POST")


def main():
    parser = argparse.ArgumentParser()
    for option in ("url", "music-dir", "beets-script", "slskd-url", "slskd-external-url"):
        parser.add_argument("--" + option, required=True)
    args = parser.parse_args()
    api = Lidarr(args.url, os.environ["LIDARR__AUTH__APIKEY"])
    api.wait()
    configure(api, args, os.environ["SLSKD_API_KEY"])
    print("Lidarr beets and slskd integrations configured.")


if __name__ == "__main__":
    main()

"""Provision direct downloads and the managed Radarr/Sonarr import hook."""

import argparse
import copy
import json
import os
import time
from urllib.error import URLError
from urllib.request import Request, urlopen


class Arr:
    def __init__(self, url, api_key):
        self.url = url.rstrip("/") + "/api/v3/"
        self.api_key = api_key

    def request(self, path, data=None, method=None):
        request = Request(
            self.url + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={"X-Api-Key": self.api_key, "Content-Type": "application/json"},
            method=method,
        )
        with urlopen(request, timeout=15) as response:
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


def configure(api, app, downloads_root, import_script):
    name = "Clean media metadata"
    current = next(
        (item for item in api.request("notification") if item["name"] == name),
        None,
    )
    if current and current["implementation"] != "CustomScript":
        raise ValueError(f"{name} already exists with another implementation")
    template = current or next(
        item for item in api.request("notification/schema")
        if item["implementation"] == "CustomScript"
    )
    desired = copy.deepcopy(template)
    # Use per-file events, including upgrades. ImportComplete would repeat
    # cleanup of every episode after Sonarr has already called OnDownload.
    for key, value in desired.items():
        if key.startswith("on") and isinstance(value, bool):
            desired[key] = key in {"onDownload", "onUpgrade"}
    desired.update(name=name, tags=[])
    fields = {field["name"]: field for field in desired["fields"]}
    fields["path"]["value"] = import_script
    fields["arguments"]["value"] = ""
    if current is None:
        desired.pop("id", None)
        api.request("notification", desired, "POST")
    elif desired != current:
        api.request(f"notification/{current['id']}", desired, "PUT")

    root = downloads_root.rstrip("/")
    for mapping in api.request("remotepathmapping"):
        if (
            mapping["remotePath"].rstrip("/") == f"{root}/complete/{app}"
            and mapping["localPath"].rstrip("/") == f"{root}/converted/{app}"
        ):
            api.request(f"remotepathmapping/{mapping['id']}", method="DELETE")

    current = api.request("config/downloadclient")
    if not current["enableCompletedDownloadHandling"]:
        api.request(
            "config/downloadclient",
            current | {"enableCompletedDownloadHandling": True},
            "PUT",
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", choices=("radarr", "sonarr"), required=True)
    for option in ("url", "downloads-root", "import-script"):
        parser.add_argument("--" + option, required=True)
    args = parser.parse_args()
    api = Arr(args.url, os.environ[f"{args.app.upper()}__AUTH__APIKEY"])
    api.wait()
    configure(api, args.app, args.downloads_root, args.import_script)
    print(f"{args.app}: direct downloads and media cleanup configured.")


if __name__ == "__main__":
    main()

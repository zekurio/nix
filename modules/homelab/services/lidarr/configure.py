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
            # download service connectivity during every system activation.
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


# Quality ranks before these scores; they only order releases within one
# quality group. Usenet titles carry no annotation and score 0, as do Slskd
# results of unknown speed, so title matching cannot tell those two apart.
# The pinned plugin appends this annotation only when peer speed is known.
# No queue annotation means an empty queue, not a guaranteed free upload slot.
PEER_SUFFIX = r"\[\d+(?:[.,]\d+)? MB/s(?:, queued behind \d+)?\]$"
SCORED_FORMATS = (
    ("Slskd peer", PEER_SUFFIX, -1000),
    ("Slskd empty queue", r"\[\d+(?:[.,]\d+)? MB/s\]$", 400),
    ("Slskd speed >= 1 MB/s", r"\[[1-9]\d*(?:[.,]\d+)? MB/s(?:, queued behind \d+)?\]$", 100),
    ("Slskd speed >= 5 MB/s", r"\[(?:[5-9]|[1-9]\d+)(?:[.,]\d+)? MB/s(?:, queued behind \d+)?\]$", 100),
    ("Slskd speed >= 10 MB/s", r"\[[1-9]\d+(?:[.,]\d+)? MB/s(?:, queued behind \d+)?\]$", 100),
)


def quality_profiles(api):
    formats = api.request("customformat")
    scores = {}
    for name, pattern, score in SCORED_FORMATS:
        current = next((item for item in formats if item["name"] == name), None)
        desired = {
            "name": name, "includeCustomFormatWhenRenaming": False,
            "specifications": [{
                "name": name, "implementation": "ReleaseTitleSpecification",
                "negate": False, "required": True,
                "fields": [{"name": "value", "value": pattern}],
            }],
        }
        if current:
            desired["id"] = current["id"]
            api.request(f"customformat/{current['id']}", desired, "PUT")
            saved = current
        else:
            saved = api.request("customformat", desired, "POST")
        scores[saved["id"]] = score

    profiles = api.request("qualityprofile")
    template = next(profile for profile in profiles if any(item.get("name") == "Lossless" for item in profile["items"]))
    preferred_id = None
    for name, fallback in (("Lossless preferred", True), ("Lossless only", False)):
        current = next((profile for profile in profiles if profile["name"] == name), None)
        # Adopt the stock Lossless profile so existing artists get the policy.
        if current is None and fallback:
            current = next((profile for profile in profiles if profile["name"] == "Lossless"), None)
        desired = copy.deepcopy(current or template)
        desired.pop("id", None)
        # The minimum equals the peer penalty, so slow or queued peers stay eligible
        # as a fallback.
        desired.update(name=name, upgradeAllowed=True, minFormatScore=-1000, cutoffFormatScore=0)
        for item in desired["items"]:
            allowed = item.get("name") == "Lossless" or (fallback and item.get("name") == "High Quality Lossy")
            item["allowed"] = allowed
            for quality in item.get("items", []):
                quality["allowed"] = allowed
            # The cutoff is the whole group, so 24-bit files are accepted without
            # forcing a 24-bit upgrade.
            if item.get("name") == "Lossless":
                desired["cutoff"] = item["id"]
        desired["formatItems"] = [item | {"score": scores.get(item["format"], item["score"])} for item in desired["formatItems"]]
        if current:
            desired["id"] = current["id"]
            api.request(f"qualityprofile/{current['id']}", desired, "PUT")
            saved = desired
        else:
            saved = api.request("qualityprofile", desired, "POST")
        if fallback:
            preferred_id = saved["id"]
    return preferred_id


def configure(api, args, slskd_key, sabnzbd_key=None):
    preferred_profile = quality_profiles(api)
    # Beets owns tags; Lidarr owns downloads and paths. Watch for Copyparty's
    # separate beets importer adding files to the same music root.
    api.settings("config/metadataprovider", writeAudioTags="no")
    api.settings("config/mediamanagement", watchLibraryForChanges=True)
    # With renaming disabled, plugin downloads land in the artist root. The
    # beets hook needs an album folder so it cannot retag the whole artist.
    # The hook is pattern 1 of https://wiki.servarr.com/lidarr/beets-integration.
    api.settings("config/naming", renameTracks=True)
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
        # Loses ties to the Usenet indexers, which Prowlarr syncs at priorities
        # 1 and 2 (set in its UI, not here).
        priority=50,
    )

    if args.sabnzbd_url:
        if not sabnzbd_key:
            raise ValueError("SABNZBD_API_KEY is required with --sabnzbd-url")
        sabnzbd = urlsplit(args.sabnzbd_url)
        api.provider(
            "downloadclient", "SABnzbd", "Sabnzbd",
            {
                "host": sabnzbd.hostname,
                "port": sabnzbd.port or (443 if sabnzbd.scheme == "https" else 80),
                "urlBase": sabnzbd.path.rstrip("/"),
                "useSsl": sabnzbd.scheme == "https",
                "apiKey": sabnzbd_key,
                "musicCategory": "lidarr",
            },
            enable=True, removeCompletedDownloads=True,
        )

    if not any(root["path"] == args.music_dir for root in api.request("rootfolder")):
        api.request("rootfolder", {
            "name": "Music",
            "path": args.music_dir,
            "defaultQualityProfileId": preferred_profile,
            "defaultMetadataProfileId": api.request("metadataprofile")[0]["id"],
            "defaultMonitorOption": "none",
            "defaultNewItemMonitorOption": "none",
            "defaultTags": [],
        }, "POST")

    for root in api.request("rootfolder"):
        if root["path"] == args.music_dir and root["defaultQualityProfileId"] != preferred_profile:
            api.request(f"rootfolder/{root['id']}", root | {"defaultQualityProfileId": preferred_profile}, "PUT")


def main():
    parser = argparse.ArgumentParser()
    for option in ("url", "music-dir", "beets-script", "slskd-url", "slskd-external-url"):
        parser.add_argument("--" + option, required=True)
    parser.add_argument("--sabnzbd-url")
    args = parser.parse_args()
    api = Lidarr(args.url, os.environ["LIDARR__AUTH__APIKEY"])
    api.wait()
    configure(api, args, os.environ["SLSKD_API_KEY"], os.environ.get("SABNZBD_API_KEY"))
    print("Lidarr integrations configured.")


if __name__ == "__main__":
    main()

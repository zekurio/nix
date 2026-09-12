"""Provision the two integrations Configarr does not manage, without deleting others."""

import json
import os
from pathlib import Path
import time
from urllib.error import URLError
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET


def request(base_url, key, endpoint, data=None, method=None):
    req = Request(
        f"{base_url}/api/v1/{endpoint}",
        data=None if data is None else json.dumps(data).encode(),
        headers={"X-Api-Key": key, "Content-Type": "application/json"},
        method=method,
    )
    with urlopen(req, timeout=30) as response:
        body = response.read()
        return json.loads(body) if body else None


def wait_for_api(base_url, key):
    deadline = time.monotonic() + 90
    while True:
        try:
            request(base_url, key, "system/status")
            return
        except (URLError, TimeoutError):
            if time.monotonic() >= deadline:
                raise
            time.sleep(2)


def upsert(base_url, key, endpoint, implementation, name, fields, **settings):
    current = next(
        (item for item in request(base_url, key, endpoint) if item["name"] == name),
        None,
    )
    if current and current["implementation"] != implementation:
        raise ValueError(f"{name} already exists with a different implementation")
    template = current or next(
        item for item in request(base_url, key, f"{endpoint}/schema")
        if item["implementation"] == implementation
    )
    payload = dict(template, name=name, **settings)
    payload["fields"] = [dict(field) for field in template["fields"]]
    available = {field["name"] for field in payload["fields"]}
    if fields.keys() - available:
        raise ValueError(f"Unsupported {implementation} fields: {fields.keys() - available}")
    for field in payload["fields"]:
        if field["name"] in fields:
            field["value"] = fields[field["name"]]
    if payload == current:
        return
    if current:
        request(base_url, key, f"{endpoint}/{current['id']}", payload, "PUT")
    else:
        request(base_url, key, endpoint, payload, "POST")
    print(f"Configured {name}")


def main():
    credentials = Path(os.environ["CREDENTIALS_DIRECTORY"])
    lidarr_key = (credentials / "lidarr-api-key").read_text().strip()
    slskd_key = (credentials / "slskd-api-key").read_text().strip()
    prowlarr_key = ET.parse(credentials / "prowlarr-config").findtext("ApiKey")
    if not all((lidarr_key, slskd_key, prowlarr_key)):
        raise ValueError("Missing integration API key")
    lidarr = os.environ["LIDARR_URL"]
    prowlarr = os.environ["PROWLARR_URL"]
    wait_for_api(lidarr, lidarr_key)
    wait_for_api(prowlarr, prowlarr_key)
    # Only new downloads get retagged; adopting the Beets library preserves it.
    metadata = request(lidarr, lidarr_key, "config/metadataprovider")
    updated = dict(metadata, writeAudioTags="newFiles", scrubAudioTags=True,
                   embedCoverArt=True)
    if updated != metadata:
        request(lidarr, lidarr_key, f"config/metadataprovider/{metadata['id']}",
                updated, "PUT")
    upsert(lidarr, lidarr_key, "indexer", "SlskdIndexer", "Soulseek", {
        "baseUrl": os.environ["SLSKD_URL"],
        "apiKey": slskd_key,
        "onlyAudioFiles": True,
        "minimumPeerUploadSpeed": 50,
        "maximumPeerQueueLength": 150,
        "responseLimit": 150,
        "fileLimit": 10000,
        "timeoutInSeconds": 30,
        "trackCountFilter": 2,
        "normalizedSeach": True,
        "handleVolumeVariations": True,
        "useFallbackSearch": True,
        "useTrackFallback": False,
        "maxQueuedPerUser": 2,
        "concurrentSearchLimit": 1,
    }, enableRss=False, enableAutomaticSearch=True, enableInteractiveSearch=True,
       priority=50)
    upsert(prowlarr, prowlarr_key, "applications", "Lidarr", "Lidarr", {
        "baseUrl": lidarr,
        "prowlarrUrl": prowlarr,
        "apiKey": lidarr_key,
        "syncCategories": [3000, 3010, 3030, 3040, 3050, 3060],
    }, syncLevel="fullSync")


if __name__ == "__main__":
    main()

"""Run with Python + PyYAML: check.py ../configarr/templates/lidarr.yml."""

from copy import deepcopy
from itertools import product
from pathlib import Path
import re
import sys

import yaml

import provision

yaml.SafeLoader.add_constructor("!env", lambda loader, node: loader.construct_scalar(node))
config = yaml.safe_load(Path(sys.argv[1]).read_text())
formats = {cf["trash_id"]: cf for cf in config["customFormatDefinitions"]}


def score(title, profile):
    total = 0
    for assignment in config["custom_formats"]:
        points = next(s["score"] for s in assignment["assign_scores_to"] if s["name"] == profile)
        for cf_id in assignment["trash_ids"]:
            if all(bool(re.search(s["fields"]["value"], title)) != s["negate"]
                   for s in formats[cf_id]["specifications"]):
                total += points
    return total


def title(slot="⚡", speed="0.50", queue=0):
    peer = f"Artist - Album (2026) [FLAC 16bit] [👤 peer ] [{slot} {speed}MB/s ]"
    return peer + (f" [📋 {queue}]" if queue else "") + " [WEB]"


for profile in config["quality_profiles"]:
    name = profile["name"]
    usenet = score("Artist-Album-WEB-FLAC-2026-GROUP", name)
    for slot, speed, queue in product(["⚡", "❌"], ["0.05", "1.00", "10.00", "100.00"], [0, 1, 9, 10, 150]):
        assert usenet > score(title(slot, speed, queue), name) >= profile["min_format_score"]
    assert score(title(), name) > score(title(slot="❌"), name)
    assert score(title(speed="10.00"), name) > score(title(speed="1.00"), name) > score(title(), name)
    assert score(title(), name) > score(title(queue=9), name) > score(title(queue=10), name)
    assert score(title(speed="10,00"), name) == score(title(speed="10.00"), name)
    assert profile["upgrade"]["until_score"] == 0, "Availability must not cause upgrades"

# Creation, rotation and repeat runs preserve existing provider fields and IDs.
state = []
calls = []


def fake_request(base, key, endpoint, data=None, method=None):
    if data is not None:
        calls.append(method)
        state[:] = [dict(deepcopy(data), id=7)]
        return state[0]
    if endpoint.endswith("/schema"):
        return [{"implementation": "SlskdIndexer", "fields": [
            {"name": "apiKey", "value": ""}, {"name": "untouched", "value": "keep"},
        ]}]
    return deepcopy(state)


provision.request = fake_request
args = ("http://localhost", "key", "indexer", "SlskdIndexer", "Soulseek")
provision.upsert(*args, {"apiKey": "first"}, priority=50)
provision.upsert(*args, {"apiKey": "first"}, priority=50)
assert calls == ["POST"]
provision.upsert(*args, {"apiKey": "rotated"}, priority=50)
assert calls == ["POST", "PUT"] and state[0]["id"] == 7
assert state[0]["fields"][1]["value"] == "keep"
for fields in [{"unknownField": True}]:
    try:
        provision.upsert(*args, fields)
    except ValueError:
        pass
    else:
        raise AssertionError("Unknown fields must fail before writing")
assert calls == ["POST", "PUT"]
print("Lidarr scoring and integration checks passed")

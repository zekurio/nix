"""Filter Zed's known Claude and GPT models through vrouter's live catalog."""

import argparse
import copy
import fcntl
import json
import os
from pathlib import Path
import sys
import tempfile
from urllib.request import Request, urlopen

import json5


def warn(message):
    print(f"zed-vrouter-models: {message}", file=sys.stderr)


def fetch_model_ids(url, key_file):
    try:
        key = key_file.read_text().strip()
    except FileNotFoundError:
        return None
    if not key:
        return None

    request = Request(
        url.rstrip("/") + "/v1/models",
        headers={"Authorization": "Bearer " + key},
    )
    with urlopen(request, timeout=5) as response:
        body = json.load(response)
    if not isinstance(body, dict) or not isinstance(body.get("data"), list):
        raise ValueError("invalid /v1/models response")
    if any(
        not isinstance(model, dict)
        or not isinstance(model.get("id"), str)
        or not model["id"]
        for model in body["data"]
    ):
        raise ValueError("invalid model in /v1/models response")
    return {model["id"] for model in body["data"]}


def update_settings(path, catalog, ids):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Serialize activation, timer and manual runs. Read settings only after
    # the HTTP request, so Zed edits made while it was pending are retained.
    with path.with_suffix(".vrouter.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if path.is_symlink():
            raise ValueError("settings.json is a symlink; activate Home Manager first")
        original = json5.loads(path.read_text()) if path.exists() else {}
        if not isinstance(original, dict):
            raise ValueError("settings.json must contain an object")
        settings = copy.deepcopy(original)
        language_models = settings.setdefault("language_models", {})
        for kind, providers in catalog.items():
            compatible = language_models.setdefault(kind, {})
            for name, models in providers.items():
                provider = compatible.setdefault(name, {})
                if ids is None:
                    # First activation without a key or network still gets the
                    # static catalog. Later failures keep the last list.
                    provider.setdefault("available_models", models)
                else:
                    provider["available_models"] = [m for m in models if m["name"] in ids]
        if settings == original:
            return

        # Same-directory replacement is atomic on both Linux and macOS. Do not
        # rewrite on no-op refreshes: Zed watches this file for changes.
        fd, temporary = tempfile.mkstemp(prefix=".settings-", dir=path.parent)
        try:
            with os.fdopen(fd, "w") as output:
                json.dump(settings, output, indent=2)
                output.write("\n")
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--key-file", type=Path, required=True)
    parser.add_argument("--settings", type=Path, required=True)
    args = parser.parse_args(argv)
    catalog = json.loads(args.catalog.read_text())
    try:
        ids = fetch_model_ids(args.url, args.key_file)
    except Exception as error:
        warn(f"could not list models ({error}); keeping the last list")
        ids = None
    if ids is not None:
        known = {
            model["name"]
            for providers in catalog.values()
            for models in providers.values()
            for model in models
        }
        unknown = sorted(id for id in ids - known if id.startswith(("claude-", "gpt-")))
        if unknown:
            warn("no Zed metadata for " + ", ".join(unknown) + "; omitting them")
    update_settings(args.settings, catalog, ids)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        warn(str(error))
        sys.exit(1)

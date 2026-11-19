"""Sync Zed's Claude and GPT models with vrouter's live catalog."""

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


def positive(value):
    # bool is an int subclass; reject it along with zero and negatives.
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def model_metadata(model):
    """Zed's fields for what one /v1/models row describes."""
    metadata = {}
    name = model.get("display_name")
    if isinstance(name, str) and name.strip() and name != model["id"]:
        metadata["display_name"] = name.strip()
    # Zed's max_tokens is the context window.
    if positive(model.get("context_window")):
        metadata["max_tokens"] = model["context_window"]
    if positive(model.get("max_output_tokens")):
        metadata["max_output_tokens"] = model["max_output_tokens"]
    inputs = model.get("input_modalities")
    if isinstance(inputs, list) and inputs:
        metadata["images"] = "image" in inputs
    return metadata


def fetch_models(url, key_file):
    """Return {model id: model_metadata}, or None without a key."""
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
    models = {}
    for model in body["data"]:
        if (
            not isinstance(model, dict)
            or not isinstance(model.get("id"), str)
            or not model["id"]
        ):
            raise ValueError("invalid model in /v1/models response")
        models[model["id"]] = model_metadata(model)
    return models


def provider_models(entry, served):
    """The catalog's models vrouter serves, then served ones it lacks.

    Catalog models keep their own limits and take only vrouter's display
    name. The others start from the family defaults and take everything
    vrouter reports.
    """
    known = {model["name"] for model in entry["models"]}
    models = []
    for model in entry["models"]:
        if model["name"] not in served:
            continue
        model = copy.deepcopy(model)
        if name := served[model["name"]].get("display_name"):
            model["display_name"] = name
        models.append(model)
    # Newest first, as in the catalog, assuming ids sort by version.
    for model_id in sorted(served, reverse=True):
        if model_id in known or not model_id.startswith(entry["prefix"]):
            continue
        model = copy.deepcopy(entry["defaults"])
        model["name"] = model_id
        metadata = dict(served[model_id])
        if "images" in metadata:
            model["capabilities"] = model.get("capabilities", {}) | {"images": metadata.pop("images")}
        model.update(metadata)
        models.append(model)
    return models


def rename_agent_providers(value, renamed):
    if isinstance(value, dict):
        provider = value.get("provider")
        if isinstance(provider, str) and provider in renamed:
            value["provider"] = renamed[provider]
        for child in value.values():
            rename_agent_providers(child, renamed)
    elif isinstance(value, list):
        for child in value:
            rename_agent_providers(child, renamed)


def update_settings(path, catalog, served):
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
        renamed = {}
        for kind, providers in catalog.items():
            compatible = language_models.setdefault(kind, {})
            for name, entry in providers.items():
                provider = compatible.setdefault(name, {})
                if legacy := entry.get("legacy_name"):
                    renamed[legacy] = name
                    # Home Manager may already have created the new entry.
                    # Keep cached models and let the new entry win conflicts.
                    if legacy in compatible:
                        provider = compatible[name] = compatible.pop(legacy) | provider
                if served is None:
                    # First activation without a key or network still gets the
                    # static catalog. Later failures keep the last list.
                    provider.setdefault("available_models", entry["models"])
                else:
                    provider["available_models"] = provider_models(entry, served)
        rename_agent_providers(settings.get("agent"), renamed)
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
        served = fetch_models(args.url, args.key_file)
    except Exception as error:
        warn(f"could not list models ({error}); keeping the last list")
        served = None
    update_settings(args.settings, catalog, served)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        warn(str(error))
        sys.exit(1)

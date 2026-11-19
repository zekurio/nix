"""Point Codex at vrouter and limit its model list to what vrouter serves.

Codex reads <base_url>/models only in its own catalog format, which
vrouter's /v1/models does not speak, so this builds that catalog itself and
points model_catalog_json at it. Each model vrouter serves starts from
Codex's bundled entry for it, or from the newest bundled model of its family,
and takes vrouter's name, context window and reasoning levels.

Codex writes config.toml itself, for example to trust a project or save the
model /model picked, so everything else in it survives. tomllib keeps no
comments, so a rewrite drops any.
"""

import argparse
import copy
import fcntl
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import tomllib
from urllib.request import Request, urlopen

import tomli_w

# vrouter's owned_by for the accounts whose models Codex can run as-is.
OWNERS = {"codex", "openai"}
VERSION = re.compile(r"\d+(\.\d+)*")


def warn(message):
    print(f"codex-config: {message}", file=sys.stderr)


def positive(value):
    # bool is an int subclass; reject it along with zero and negatives.
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def parse(model_id):
    """gpt-6.2-sol is family gpt-sol at version [6, 2]."""
    parts = model_id.split("-")
    version = [int(n) for p in parts if VERSION.fullmatch(p) for n in p.split(".")]
    family = "-".join(p for p in parts if not VERSION.fullmatch(p))
    return family, version


def stand_in(bundled, model_id):
    """The newest bundled model of the family that is not newer than model_id."""
    family, version = parse(model_id)
    candidates = [
        m for m in bundled
        if parse(m["slug"])[0] == family and parse(m["slug"])[1] <= version
    ]
    return max(candidates, key=lambda m: parse(m["slug"])[1], default=None)


def catalog_models(bundled, served):
    by_slug = {m["slug"]: m for m in bundled}
    models = []
    for row in served:
        model_id = row["id"]
        if row.get("owned_by") not in OWNERS:
            continue
        base = by_slug.get(model_id) or stand_in(bundled, model_id)
        if base is None:
            warn(f"Codex knows no model like {model_id}; leaving it out")
            continue
        if base["slug"] != model_id:
            warn(f"Codex's catalog lacks {model_id}; using {base['slug']}'s metadata")
        model = copy.deepcopy(base)
        model["slug"] = model_id
        # vrouter lists only what the account may use, which includes models
        # the bundled catalog hides.
        model["visibility"] = "list"
        name = row.get("display_name")
        if isinstance(name, str) and name.strip():
            model["display_name"] = name.strip()
        elif base["slug"] != model_id:
            model["display_name"] = model_id
        if isinstance(row.get("description"), str) and row["description"].strip():
            model["description"] = row["description"].strip()
        if positive(row.get("context_window")):
            model["context_window"] = row["context_window"]
        efforts = [
            level["effort"] for level in row.get("supported_reasoning_levels") or []
            if isinstance(level, dict) and isinstance(level.get("effort"), str)
        ]
        if efforts:
            known = {
                level["effort"]: level["description"]
                for level in base.get("supported_reasoning_levels", [])
            }
            model["supported_reasoning_levels"] = [
                {"effort": effort, "description": known.get(effort, effort)}
                for effort in efforts
            ]
        if isinstance(row.get("default_reasoning_level"), str):
            model["default_reasoning_level"] = row["default_reasoning_level"]
        inputs = [i for i in row.get("input_modalities") or [] if i in ("text", "image")]
        if inputs:
            model["input_modalities"] = inputs
        models.append(model)
    return models


def fetch_served(url, key):
    request = Request(url.rstrip("/") + "/v1/models", headers={"Authorization": "Bearer " + key})
    with urlopen(request, timeout=10) as response:
        body = json.load(response)
    if not isinstance(body, dict) or not isinstance(body.get("data"), list):
        raise ValueError("invalid /v1/models response")
    for row in body["data"]:
        if not isinstance(row, dict) or not isinstance(row.get("id"), str) or not row["id"]:
            raise ValueError("invalid model in /v1/models response")
    return body["data"]


def write_atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(data)
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def sync_catalog(catalog, bundled, url, key):
    """Rewrite the catalog; a failure or an empty result keeps the last one."""
    try:
        models = catalog_models(bundled, fetch_served(url, key))
    except Exception as error:
        warn(f"could not list vrouter's models ({error}); keeping the last list")
        return
    if not models:
        # Codex refuses to start on an empty catalog.
        warn("vrouter serves no model Codex can use; keeping the last list")
        return
    data = (json.dumps({"models": models}, indent=2) + "\n").encode()
    if not catalog.exists() or catalog.read_bytes() != data:
        write_atomic(catalog, data)


def merge(base, extra):
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge(base[key], value)
        else:
            base[key] = value


def update(config, settings, provider_id, provider, catalog):
    """Apply the settings, and the provider and catalog when given.

    Without a provider both come out again. A model_catalog_json pointing at
    a missing file goes too: Codex refuses to start on it.
    """
    merge(config, settings)
    pointer = config.get("model_catalog_json")
    if catalog is not None:
        config["model_catalog_json"] = str(catalog)
    elif isinstance(pointer, str) and (provider is None or not Path(pointer).is_file()):
        del config["model_catalog_json"]
    providers = config.get("model_providers")
    if provider is not None:
        # Replaced whole, so a key dropped here leaves the file too.
        config.setdefault("model_providers", {})[provider_id] = provider
        config["model_provider"] = provider_id
        return
    if isinstance(providers, dict):
        providers.pop(provider_id, None)
        if not providers:
            del config["model_providers"]
    if config.get("model_provider") == provider_id:
        del config["model_provider"]


def read_key(key_file):
    try:
        return key_file.read_text().strip()
    except FileNotFoundError:
        return ""


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--settings", type=json.loads, required=True)
    parser.add_argument("--provider-id", required=True)
    parser.add_argument("--provider", type=json.loads, required=True)
    parser.add_argument("--key-file", type=Path, required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--bundled", type=Path, required=True)
    args = parser.parse_args(argv)

    key = read_key(args.key_file)
    if key:
        bundled = json.loads(args.bundled.read_text())["models"]
        sync_catalog(args.catalog, bundled, args.url, key)

    path = args.config
    path.parent.mkdir(parents=True, exist_ok=True)
    # Serialize activation, timer and manual runs.
    with path.with_name(".config.toml.vrouter.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        original = tomllib.loads(path.read_text()) if path.exists() else {}
        config = copy.deepcopy(original)
        update(
            config,
            args.settings,
            args.provider_id,
            args.provider if key else None,
            args.catalog if key and args.catalog.is_file() else None,
        )
        if config != original:
            write_atomic(path, tomli_w.dumps(config).encode())


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        warn(str(error))
        sys.exit(1)

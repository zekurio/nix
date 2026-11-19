"""Merge Home Manager's keys into Codex's config.toml.

Codex writes the file itself, for example to trust a project or save the
model /model picked, so everything else in it survives. tomllib keeps no
comments, so a rewrite drops any.
"""

import argparse
import copy
import json
import os
from pathlib import Path
import tempfile
import tomllib

import tomli_w


def merge(base, extra):
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge(base[key], value)
        else:
            base[key] = value


def update(config, settings, provider_id, provider):
    merge(config, settings)
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


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--settings", type=json.loads, required=True)
    parser.add_argument("--provider-id", required=True)
    # Omitted, the provider comes out again.
    parser.add_argument("--provider", type=json.loads)
    args = parser.parse_args(argv)

    path = args.config
    original = tomllib.loads(path.read_text()) if path.exists() else {}
    config = copy.deepcopy(original)
    update(config, args.settings, args.provider_id, args.provider)
    if config == original:
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".config-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            tomli_w.dump(config, output)
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    main()

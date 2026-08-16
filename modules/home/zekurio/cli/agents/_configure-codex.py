import json
import os
import stat
import tempfile
from pathlib import Path

import tomlkit


CODEX_DIR = Path.home() / ".codex"
ROUTER_DIR = CODEX_DIR / "codex-router"


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    current_mode = (
        stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    )

    with tempfile.NamedTemporaryFile(
        mode="w", dir=path.parent, prefix=f".{path.name}.", delete=False
    ) as temporary:
        temporary.write(content)
        temporary_path = Path(temporary.name)

    temporary_path.chmod(current_mode)
    os.replace(temporary_path, path)


def configure_theme() -> None:
    path = CODEX_DIR / "config.toml"
    if path.exists():
        document = tomlkit.parse(path.read_text())
    else:
        document = tomlkit.document()
    document["model"] = "kimi-api/k3-1m"
    document["model_reasoning_effort"] = "max"
    desktop = document.setdefault("desktop", tomlkit.table())

    desktop["followUpQueueMode"] = "queue"
    desktop["enabled-reasoning-efforts"] = [
        "low",
        "medium",
        "high",
        "xhigh",
        "ultra",
        "max",
    ]
    desktop["localeOverride"] = "en-US"
    desktop["appearanceLightCodeThemeId"] = "catppuccin"
    desktop["appearanceDarkCodeThemeId"] = "catppuccin"

    themes = {
        "appearanceLightChromeTheme": {
            "accent": "#1e66f5",
            "contrast": 45,
            "ink": "#4c4f69",
            "opaqueWindows": False,
            "surface": "#eff1f5",
            "semanticColors": {
                "diffAdded": "#40a02b",
                "diffRemoved": "#d20f39",
                "skill": "#1e66f5",
            },
        },
        "appearanceDarkChromeTheme": {
            "accent": "#8caaee",
            "contrast": 60,
            "ink": "#c6d0f5",
            "opaqueWindows": False,
            "surface": "#303446",
            "semanticColors": {
                "diffAdded": "#a6d189",
                "diffRemoved": "#e78284",
                "skill": "#8caaee",
            },
        },
    }

    for name, values in themes.items():
        theme = desktop.setdefault(name, tomlkit.table())
        for key in ("accent", "contrast", "ink", "opaqueWindows", "surface"):
            theme[key] = values[key]
        theme.setdefault("fonts", tomlkit.table())
        semantic_colors = theme.setdefault("semanticColors", tomlkit.table())
        for key, value in values["semanticColors"].items():
            semantic_colors[key] = value

    rendered = tomlkit.dumps(document)
    if not path.exists() or path.read_text() != rendered:
        atomic_write(path, rendered)


def configure_router_catalog() -> None:
    files = {
        "enabled-providers.json": {"version": 1, "providers": ["kimi-api"]},
        "model-picker.json": {
            "version": 1,
            "hidden": [
                "kimi-oauth/k3",
                "kimi-oauth/kimi-for-coding",
                "kimi-oauth/kimi-for-coding-highspeed",
                "kimi-api/kimi-k3",
                "gpt-5.2",
                "gpt-5.5",
            ],
        },
        "user-models.json": {
            "version": 1,
            "models": [
                {
                    "slug": "kimi-api/k3-1m",
                    "gatewayModel": "kimi-api-k3-1m",
                    "upstreamModel": "k3",
                    "provider": "kimi-api",
                    "listed": True,
                    "multiAgentVersion": "v2",
                    "displayName": "Kimi K3 1M (API Key)",
                    "description": (
                        "Kimi K3 with a 1M-token context window using a "
                        "Kimi Code subscription API key. Requires an "
                        "Allegretto plan or higher for the full context "
                        "window."
                    ),
                    "priority": 4,
                    "defaultEffort": "high",
                    "reasoningLevels": [
                        {"effort": "low", "description": "Faster reasoning"},
                        {
                            "effort": "high",
                            "description": "Balanced deep reasoning",
                        },
                        {
                            "effort": "max",
                            "description": "Maximum reasoning depth",
                        },
                    ],
                    "contextWindow": 1048576,
                    "autoCompact": 900000,
                    "inputModalities": ["text", "image"],
                    "requestProfile": "kimi-k3",
                    "supportsImageDetailOriginal": True,
                    "compHash": "kimi-code-api-k3-1m-user-v1",
                },
                {
                    "slug": "kimi-api/k3-256k",
                    "gatewayModel": "kimi-api-k3-256k",
                    "upstreamModel": "k3-256k",
                    "provider": "kimi-api",
                    "listed": True,
                    "multiAgentVersion": "v2",
                    "displayName": "Kimi K3 256K (API Key)",
                    "description": (
                        "Kimi K3 with a fixed 256K-token context window "
                        "using a Kimi Code subscription API key."
                    ),
                    "priority": 5,
                    "defaultEffort": "high",
                    "reasoningLevels": [
                        {"effort": "low", "description": "Faster reasoning"},
                        {
                            "effort": "high",
                            "description": "Balanced deep reasoning",
                        },
                        {
                            "effort": "max",
                            "description": "Maximum reasoning depth",
                        },
                    ],
                    "contextWindow": 262144,
                    "autoCompact": 235000,
                    "inputModalities": ["text", "image"],
                    "requestProfile": "kimi-k3",
                    "supportsImageDetailOriginal": True,
                    "compHash": "kimi-code-api-k3-256k-user-v1",
                },
            ],
        },
    }

    for name, value in files.items():
        content = json.dumps(value, indent=2) + "\n"
        path = ROUTER_DIR / name
        if not path.exists() or path.read_text() != content:
            atomic_write(path, content)


configure_theme()
configure_router_catalog()

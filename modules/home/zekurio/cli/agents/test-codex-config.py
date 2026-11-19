import importlib.util
import json
from pathlib import Path
import tempfile
import tomllib
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "codex_config", Path(__file__).with_name("codex-config.py")
)
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

BUNDLED = [
    {
        "slug": "gpt-6.2-sol",
        "display_name": "GPT-6.2-Sol",
        "visibility": "list",
        "context_window": 500000,
        "default_reasoning_level": "low",
        "supported_reasoning_levels": [
            {"effort": "low", "description": "Fast"},
            {"effort": "high", "description": "Deep"},
        ],
        "base_instructions": "sol",
    },
    {"slug": "gpt-6.1-sol", "display_name": "GPT-6.1-Sol", "visibility": "list",
     "supported_reasoning_levels": [], "base_instructions": "old sol"},
    {"slug": "gpt-daybreak-blue-latest", "display_name": "Daybreak", "visibility": "hide",
     "supported_reasoning_levels": [], "base_instructions": "daybreak"},
]
PROVIDER = {"name": "vrouter", "base_url": "https://vrouter.example/v1"}


class CatalogModels(unittest.TestCase):
    def test_known_model_takes_vrouter_metadata(self):
        [model] = sync.catalog_models(BUNDLED, [{
            "id": "gpt-6.2-sol", "owned_by": "codex", "display_name": "Sol",
            "context_window": 400000, "default_reasoning_level": "high",
            "supported_reasoning_levels": [{"effort": "high"}, {"effort": "ultra"}],
        }])
        self.assertEqual(model["display_name"], "Sol")
        self.assertEqual(model["context_window"], 400000)
        self.assertEqual(model["default_reasoning_level"], "high")
        self.assertEqual(model["supported_reasoning_levels"], [
            {"effort": "high", "description": "Deep"},
            {"effort": "ultra", "description": "ultra"},
        ])
        self.assertEqual(model["base_instructions"], "sol")

    def test_unknown_model_borrows_newest_older_family_member(self):
        [model] = sync.catalog_models(BUNDLED, [{"id": "gpt-6.3-sol", "owned_by": "codex"}])
        self.assertEqual(model["slug"], "gpt-6.3-sol")
        self.assertEqual(model["display_name"], "gpt-6.3-sol")
        self.assertEqual(model["base_instructions"], "sol")

    def test_served_hidden_model_is_listed(self):
        [model] = sync.catalog_models(BUNDLED, [{"id": "gpt-daybreak-blue-latest", "owned_by": "codex"}])
        self.assertEqual(model["visibility"], "list")

    def test_skips_claude_and_unknown_families(self):
        models = sync.catalog_models(BUNDLED, [
            {"id": "claude-opus-5-5", "owned_by": "claude"},
            {"id": "gpt-7-nova", "owned_by": "codex"},
        ])
        self.assertEqual(models, [])


class Main(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.config = self.dir / "config.toml"
        self.catalog = self.dir / "vrouter-models.json"
        self.key = self.dir / "api-key"
        self.bundled = self.dir / "bundled.json"
        self.bundled.write_text(json.dumps({"models": BUNDLED}))
        self.config.write_text('model = "gpt-6.2-sol"\n[projects."/x"]\ntrust_level = "trusted"\n')

    def run_sync(self, served=None, error=None):
        def fetch(url, key):
            if error:
                raise error
            return served
        with patch.object(sync, "fetch_served", side_effect=fetch), patch.object(sync, "warn"):
            sync.main([
                "--config", str(self.config), "--settings", '{"check_for_update_on_startup": false}',
                "--provider-id", "vrouter", "--provider", json.dumps(PROVIDER),
                "--key-file", str(self.key), "--url", "https://vrouter.example",
                "--catalog", str(self.catalog), "--bundled", str(self.bundled),
            ])
        return tomllib.loads(self.config.read_text())

    def test_with_key_points_codex_at_vrouter(self):
        self.key.write_text("secret\n")
        config = self.run_sync([{"id": "gpt-6.2-sol", "owned_by": "codex"}])
        self.assertEqual(config["model_provider"], "vrouter")
        self.assertEqual(config["model_providers"]["vrouter"], PROVIDER)
        self.assertEqual(config["model_catalog_json"], str(self.catalog))
        self.assertEqual(config["projects"]["/x"]["trust_level"], "trusted")
        self.assertFalse(config["check_for_update_on_startup"])
        slugs = [m["slug"] for m in json.loads(self.catalog.read_text())["models"]]
        self.assertEqual(slugs, ["gpt-6.2-sol"])

    def test_failed_fetch_keeps_last_catalog(self):
        self.key.write_text("secret")
        self.run_sync([{"id": "gpt-6.2-sol", "owned_by": "codex"}])
        before = self.catalog.read_text()
        config = self.run_sync(error=OSError("offline"))
        self.assertEqual(self.catalog.read_text(), before)
        self.assertEqual(config["model_catalog_json"], str(self.catalog))

    def test_first_failed_fetch_leaves_bundled_catalog(self):
        self.key.write_text("secret")
        config = self.run_sync(error=OSError("offline"))
        self.assertNotIn("model_catalog_json", config)
        self.assertEqual(config["model_provider"], "vrouter")

    def test_without_key_removes_provider_and_catalog(self):
        self.key.write_text("secret")
        self.run_sync([{"id": "gpt-6.2-sol", "owned_by": "codex"}])
        self.key.unlink()
        config = self.run_sync()
        self.assertNotIn("model_provider", config)
        self.assertNotIn("model_providers", config)
        self.assertNotIn("model_catalog_json", config)
        self.assertEqual(config["model"], "gpt-6.2-sol")

    def test_drops_dangling_catalog_pointer(self):
        self.key.write_text("secret")
        self.config.write_text('model_catalog_json = "/nix/store/gone-codex-models.json"\n')
        config = self.run_sync(error=OSError("offline"))
        self.assertNotIn("model_catalog_json", config)


if __name__ == "__main__":
    unittest.main()

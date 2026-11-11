import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError


spec = importlib.util.spec_from_file_location(
    "zed_vrouter_models", Path(__file__).with_name("zed-vrouter-models.py")
)
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

CLAUDE = "Anthropic (vrouter)"
GPT = "OpenAI (vrouter)"
CATALOG = {
    "anthropic_compatible": {
        CLAUDE: [
            {
                "name": "claude-opus-5-5",
                "max_tokens": 1000000,
                "mode": {"type": "adaptive"},
                "extra_beta_headers": ["thinking-binding-controls-2026-08-01"],
            },
            {"name": "claude-sonnet-5-5", "max_tokens": 1000000},
        ]
    },
    "openai_compatible": {
        GPT: [
            {
                "name": "gpt-6.1-sol",
                "max_tokens": 272000,
                "reasoning_effort": "high",
                "capabilities": {"chat_completions": False, "images": True},
            },
            {"name": "gpt-6.1-terra", "max_tokens": 272000},
        ]
    },
}


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.settings = self.root / "zed" / "settings.json"
        self.key = self.root / "api-key"
        self.catalog = self.root / "catalog.json"
        self.catalog.write_text(json.dumps(CATALOG))

    def read(self):
        return json.loads(self.settings.read_text())

    def write(self, settings):
        self.settings.parent.mkdir(exist_ok=True)
        self.settings.write_text(json.dumps(settings))

    def run_sync(self):
        sync.main([
            "--catalog", str(self.catalog),
            "--url", "https://vrouter.example",
            "--key-file", str(self.key),
            "--settings", str(self.settings),
        ])

    def test_filters_both_providers_and_preserves_metadata(self):
        sync.update_settings(
            self.settings, CATALOG,
            {"claude-opus-5-5", "gpt-6.1-sol", "gpt-unknown", "other-model"},
        )
        models = self.read()["language_models"]
        self.assertEqual(models["anthropic_compatible"][CLAUDE]["available_models"],
                         CATALOG["anthropic_compatible"][CLAUDE][:1])
        self.assertEqual(models["openai_compatible"][GPT]["available_models"],
                         CATALOG["openai_compatible"][GPT][:1])
        self.assertEqual(self.settings.stat().st_mode & 0o777, 0o600)

    def test_preserves_other_settings_and_accepts_jsonc(self):
        self.settings.parent.mkdir()
        self.settings.write_text('''{
          // Zed accepts comments and trailing commas.
          "theme": "DankShell Dark",
          "agent": {"default_model": {"model": "claude-opus-5-5"}},
          "language_models": {
            "openai_compatible": {
              "other": {"available_models": [{"name": "local"}]},
              "OpenAI (vrouter)": {"api_url": "https://vrouter.example/v1"},
            },
          },
        }''')
        sync.update_settings(self.settings, CATALOG, {"gpt-6.1-sol"})
        settings = self.read()
        self.assertEqual(settings["theme"], "DankShell Dark")
        self.assertEqual(settings["agent"]["default_model"]["model"], "claude-opus-5-5")
        providers = settings["language_models"]["openai_compatible"]
        self.assertEqual(providers[GPT]["api_url"], "https://vrouter.example/v1")
        self.assertEqual(providers["other"]["available_models"], [{"name": "local"}])

    def test_noop_does_not_replace_file(self):
        sync.update_settings(self.settings, CATALOG, {"gpt-6.1-sol"})
        before = self.settings.stat()
        sync.update_settings(self.settings, CATALOG, {"gpt-6.1-sol"})
        after = self.settings.stat()
        self.assertEqual((before.st_ino, before.st_mtime_ns),
                         (after.st_ino, after.st_mtime_ns))

    def test_empty_catalog_clears_both_lists(self):
        sync.update_settings(self.settings, CATALOG, set())
        for providers in self.read()["language_models"].values():
            for provider in providers.values():
                self.assertEqual(provider["available_models"], [])

    def test_missing_or_empty_key_bootstraps_without_fetching(self):
        with patch.object(sync, "urlopen") as fetch:
            self.run_sync()
            self.key.write_text(" \n")
            self.run_sync()
            fetch.assert_not_called()
        for kind, providers in CATALOG.items():
            for name, models in providers.items():
                self.assertEqual(self.read()["language_models"][kind][name]["available_models"], models)

    def test_failure_preserves_last_list_even_when_empty(self):
        sync.update_settings(self.settings, CATALOG, {"claude-opus-5-5"})
        before = self.settings.read_bytes()
        for failure in (URLError("offline"), TimeoutError("timed out"),
                        ValueError("invalid response")):
            with self.subTest(failure=failure):
                with patch.object(sync, "fetch_model_ids", side_effect=failure), \
                     contextlib.redirect_stderr(io.StringIO()) as output:
                    self.run_sync()
                self.assertIn("keeping the last list", output.getvalue())
                self.assertEqual(self.settings.read_bytes(), before)
        # A rebuild can change metadata; without a successful fetch it must
        # not replace cached lists with the new static catalog either.
        changed = copy.deepcopy(CATALOG)
        changed["anthropic_compatible"][CLAUDE][0]["max_tokens"] = 42
        sync.update_settings(self.settings, changed, None)
        self.assertEqual(self.settings.read_bytes(), before)

    def test_unknown_models_warn_but_are_not_added(self):
        with patch.object(sync, "fetch_model_ids", return_value={"claude-new", "gpt-new"}), \
             contextlib.redirect_stderr(io.StringIO()) as output:
            self.run_sync()
        self.assertIn("claude-new", output.getvalue())
        self.assertIn("gpt-new", output.getvalue())
        for providers in self.read()["language_models"].values():
            for provider in providers.values():
                self.assertEqual(provider["available_models"], [])

    def test_invalid_settings_and_symlinks_are_not_overwritten(self):
        self.settings.parent.mkdir()
        for invalid in ("{broken", "[]", '{"language_models": null}'):
            with self.subTest(invalid=invalid):
                self.settings.write_text(invalid)
                with self.assertRaises((ValueError, AttributeError)):
                    sync.update_settings(self.settings, CATALOG, set())
                self.assertEqual(self.settings.read_text(), invalid)
        self.settings.unlink()
        self.settings.symlink_to(self.catalog)
        with self.assertRaisesRegex(ValueError, "activate Home Manager"):
            sync.update_settings(self.settings, CATALOG, set())
        self.assertEqual(json.loads(self.catalog.read_text()), CATALOG)
        self.assertTrue(self.settings.is_symlink())

    def test_fetch_auth_url_timeout_and_deduplication(self):
        self.key.write_text("test-key\n")
        response = io.BytesIO(b'{"data":[{"id":"gpt-6.1-sol"},{"id":"gpt-6.1-sol"}]}')
        with patch.object(sync, "urlopen", return_value=response) as fetch:
            ids = sync.fetch_model_ids("https://vrouter.example/", self.key)
        self.assertEqual(ids, {"gpt-6.1-sol"})
        request = fetch.call_args.args[0]
        self.assertEqual(request.full_url, "https://vrouter.example/v1/models")
        self.assertEqual(request.get_header("Authorization"), "Bearer test-key")
        self.assertEqual(fetch.call_args.kwargs["timeout"], 5)

    def test_malformed_catalogs_and_http_errors_keep_settings(self):
        self.key.write_text("test-key")
        sync.update_settings(self.settings, CATALOG, {"gpt-6.1-sol"})
        before = self.settings.read_bytes()
        for body in (b"not json", b"{}", b'{"data":null}', b'{"data":[{}]}',
                     b'{"data":[{"id":42}]}', b'{"data":[{"id":""}]}'):
            with self.subTest(body=body):
                with patch.object(sync, "urlopen", return_value=io.BytesIO(body)), \
                     contextlib.redirect_stderr(io.StringIO()):
                    self.run_sync()
                self.assertEqual(self.settings.read_bytes(), before)
        for status in (401, 500):
            error = HTTPError("https://vrouter.example/v1/models", status, "error", {}, None)
            with patch.object(sync, "urlopen", side_effect=error), \
                 contextlib.redirect_stderr(io.StringIO()):
                self.run_sync()
            self.assertEqual(self.settings.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()

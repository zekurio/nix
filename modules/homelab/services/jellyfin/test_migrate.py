import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("migrate.sh")
INVITERR = SCRIPT.parent.parent / "inviterr" / "configure.py"


class MigrationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "jellyfin"
        self.target = self.root / "ferrofin"
        for name in (
            "data/jellyfin.db",
            "data/jellyfin.db-wal",
            "data/jellyfin.db-shm",
            "data/playlists/list.xml",
            "data/collections/list.xml",
            "root/default/TV/.mblink",
            "metadata/poster.jpg",
            "config/network.xml",
            "plugins/tvdb.dll",
        ):
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(name)

    def run_copy(self, **kwargs):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.source), str(self.target)],
            capture_output=True,
            text=True,
            **kwargs,
        )

    def test_copy_keeps_source_and_later_server_changes(self):
        before = {
            path.relative_to(self.source): path.read_bytes()
            for path in self.source.rglob("*")
            if path.is_file()
        }
        self.assertEqual(self.run_copy().returncode, 0)
        for name, content in before.items():
            self.assertEqual((self.source / name).read_bytes(), content)
            if name.parts[0] != "plugins":
                self.assertEqual((self.target / name).read_bytes(), content)
        self.assertFalse((self.target / "plugins").exists())
        database = self.target / "data/jellyfin.db"
        database.write_text("new watch progress")
        self.assertEqual(self.run_copy().returncode, 0)
        self.assertEqual(database.read_text(), "new watch progress")

    def test_interrupted_copy_resumes_and_removes_old_wal(self):
        commands = self.root / "commands"
        commands.mkdir()
        wrapper = commands / "rsync"
        wrapper.write_text(
            '#!/bin/sh\ncase "$*" in *metadata*) exit 1;; esac\n'
            f'exec "{shutil.which("rsync")}" "$@"\n'
        )
        wrapper.chmod(0o755)
        environment = dict(os.environ, PATH=f"{commands}{os.pathsep}{os.environ['PATH']}")
        self.assertNotEqual(self.run_copy(env=environment).returncode, 0)
        self.assertTrue((self.target / ".jellyfin-copy-pending").exists())
        (self.source / "data/jellyfin.db-wal").unlink()
        (self.source / "data/jellyfin.db-shm").unlink()
        self.assertEqual(self.run_copy().returncode, 0)
        self.assertEqual((self.target / "metadata/poster.jpg").read_text(), "metadata/poster.jpg")
        self.assertFalse((self.target / "data/jellyfin.db-wal").exists())
        self.assertFalse((self.target / "data/jellyfin.db-shm").exists())
        self.assertFalse((self.target / ".jellyfin-copy-pending").exists())

    def test_existing_ferrofin_database_is_kept(self):
        self.target.mkdir()
        database = self.target / "ferrofin.db"
        database.write_text("existing database")
        self.assertEqual(self.run_copy().returncode, 0)
        self.assertEqual(database.read_text(), "existing database")
        self.assertFalse((self.target / "data").exists())

    def test_copy_cannot_resume_after_adoption(self):
        (self.target / "data").mkdir(parents=True)
        (self.target / ".jellyfin-copy-pending").touch()
        database = self.target / "data/jellyfin.db"
        database.write_text("adopted database")
        (self.target / "data/jellyfin.db.pre-ferrofin").touch()
        self.assertNotEqual(self.run_copy().returncode, 0)
        self.assertEqual(database.read_text(), "adopted database")

    def test_missing_source_does_not_create_a_fresh_server(self):
        (self.source / "data/jellyfin.db").unlink()
        self.assertNotEqual(self.run_copy().returncode, 0)
        self.assertFalse(self.target.exists())

    def test_missing_copied_database_blocks_startup(self):
        self.target.mkdir()
        (self.target / ".jellyfin-copy-complete").touch()
        self.assertNotEqual(self.run_copy().returncode, 0)

    def test_inviterr_path_change_keeps_settings_and_mode(self):
        settings = self.root / "inviterr.json"
        settings.write_text(json.dumps({
            "jellyfin": {"configPath": str(self.source), "apiKey": "test-key"},
            "other": "keep",
        }))
        settings.chmod(0o600)
        for directory in (self.target / "data", self.source):
            subprocess.run(
                [sys.executable, str(INVITERR), str(settings), str(directory)],
                check=True,
            )
            result = json.loads(settings.read_text())
            self.assertEqual(result["jellyfin"]["configPath"], str(directory))
            self.assertEqual(result["jellyfin"]["apiKey"], "test-key")
            self.assertEqual(result["other"], "keep")
            self.assertEqual(settings.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()

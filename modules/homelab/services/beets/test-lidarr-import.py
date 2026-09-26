import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml


spec = importlib.util.spec_from_file_location("lidarr_import", sys.argv.pop(1))
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)
config_path = sys.argv.pop(1)


class LidarrImportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.music = Path(self.temporary.name) / "music"
        self.artist = self.music / "Artist"
        self.album = self.artist / "Album"
        self.tracks = [self.album / f"Disc {disc}/01 - Song.flac" for disc in (1, 2)]
        for track in self.tracks:
            track.parent.mkdir(parents=True)
            track.write_bytes(b"untouched audio")
        self.environment = {
            "lidarr_eventtype": "AlbumDownload",
            "lidarr_artist_path": str(self.artist),
            "lidarr_addedtrackpaths": "|".join(map(str, self.tracks)),
        }

    def test_multi_disc_release_uses_album_directory(self):
        self.assertEqual(hook.album_directory(self.environment, self.music), self.album)

    def test_rejects_artist_wide_and_outside_paths(self):
        outside = Path(self.temporary.name) / "outside.flac"
        outside.write_bytes(b"untouched audio")
        other_album = self.artist / "Other album/01.flac"
        other_album.parent.mkdir()
        other_album.write_bytes(b"untouched audio")
        symlink = self.album / "outside.flac"
        symlink.symlink_to(outside)
        for paths in ("", str(outside), str(symlink), f"{self.tracks[0]}|{other_album}"):
            with self.subTest(paths=paths), self.assertRaises(ValueError):
                hook.album_directory(self.environment | {"lidarr_addedtrackpaths": paths}, self.music)

    def test_test_event_needs_no_paths_or_beets(self):
        with patch.dict(os.environ, {"lidarr_eventtype": "Test"}, clear=True):
            with patch.object(hook.subprocess, "run") as run:
                hook.main()
                run.assert_not_called()

    def test_separate_database_and_no_file_moves(self):
        with open(config_path) as handle:
            config = yaml.safe_load(handle)
        self.assertFalse(config["import"]["move"])
        self.assertFalse(config["import"]["copy"])
        self.assertFalse(config["import"]["incremental"])
        self.assertTrue(config["import"]["write"])
        databases = []

        def run(command, *, check, env):
            self.assertTrue(check)
            self.assertEqual(command[command.index("--config") + 1], config_path)
            database = Path(command[command.index("--library") + 1])
            self.assertEqual(database.parent, Path(env["BEETSDIR"]))
            self.assertTrue(database.parent.is_dir())
            self.assertNotEqual(str(database), config["library"])
            self.assertEqual(command[-1], str(self.album))
            self.assertIn("--noincremental", command)
            database.write_text("temporary library")
            databases.append(database)

        arguments = ["hook", "--beet", "beet", "--config", config_path,
                     "--music-dir", str(self.music)]
        with patch.dict(os.environ, self.environment, clear=True), patch.object(sys, "argv", arguments):
            with patch.object(hook.subprocess, "run", side_effect=run):
                hook.main()
                hook.main()
        self.assertNotEqual(databases[0], databases[1])
        self.assertTrue(all(not database.exists() for database in databases))
        for track in self.tracks:
            self.assertEqual(track.read_bytes(), b"untouched audio")


unittest.main()

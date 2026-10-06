"""Regression checks with real containers. Run with Python and FFmpeg on PATH."""

import copy
import errno
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cleanup = load("cleanup", "clean-import.py")
configure = load("configure", "configure.py")


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", *map(str, args)], check=True)


def packet_hashes(path):
    result = subprocess.run([
        "ffprobe", "-v", "error", "-show_packets", "-show_data_hash", "sha256",
        "-show_entries", "packet=stream_index,data_hash", "-of", "json", str(path),
    ], check=True, capture_output=True, text=True)
    streams = {}
    for packet in json.loads(result.stdout)["packets"]:
        streams.setdefault(packet["stream_index"], []).append(packet["data_hash"])
    indexes = [stream["index"] for stream in cleanup.probe(path)["streams"]
               if cleanup.keep_stream(stream) and stream["codec_type"] != "attachment"]
    return [streams.get(index, []) for index in indexes]


class Containers(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="media-cleanup-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def fixture(self):
        subtitles = self.root / "captions.srt"
        subtitles.write_text("1\n00:00:00,000 --> 00:00:01,000\nA subtitle.\n")
        chapters = self.root / "chapters.txt"
        chapters.write_text(";FFMETADATA1\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=0\nEND=1000\ntitle=Opening\ncomment=Release spam\n")
        # The muxer needs attachment bytes and MIME information, not a valid
        # font parser. Packet copying must preserve these bytes verbatim.
        font = self.root / "subtitle.ttf"
        font.write_bytes(b"\x00\x01\x00\x00subtitle font fixture")
        cover = self.root / "cover.jpg"
        ffmpeg("-f", "lavfi", "-i", "color=c=red:s=32x32", "-frames:v", "1", cover)
        path = self.root / "Episode with spaces.mkv"
        ffmpeg(
            "-f", "lavfi", "-i", "testsrc2=s=320x180:r=10:d=1",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
            "-i", subtitles, "-f", "ffmetadata", "-i", chapters,
            "-map", "0:v", "-map", "1:a", "-map", "2:s",
            "-c:v", "libx264", "-c:a", "aac", "-c:s", "srt", "-map_chapters", "3",
            "-metadata", "title=Release title spam", "-metadata", "comment=Download URL",
            "-metadata:s:v:0", "title=Video release spam",
            "-metadata:s:v:0", "comment=Video download URL",
            "-metadata:s:a:0", "language=ger", "-metadata:s:a:0", "title=Release commentary spam",
            "-metadata:s:a:0", "comment=Download URL", "-disposition:a:0", "default+comment",
            "-metadata:s:s:0", "language=jpn", "-metadata:s:s:0", "title=Signs and Songs SDH spam",
            "-disposition:s:0", "forced+hearing_impaired", "-attach", cover, "-attach", font,
            "-metadata:s:t:0", "mimetype=image/jpeg", "-metadata:s:t:1", "mimetype=application/x-truetype-font",
            path,
        )
        path.chmod(0o664)
        return path

    def test_mkv_preserves_packets_flags_fonts_and_chapters(self):
        path = self.fixture()
        before = cleanup.probe(path)
        hashes = packet_hashes(path)
        stat = path.stat()
        # Model the service's user namespace rejecting chown of its unmapped
        # shared group. Cleanup must still succeed and retain that group.
        with patch.object(cleanup.os, "chown", side_effect=OSError(errno.EINVAL, "Invalid argument")):
            cleanup.clean(path)
        after = cleanup.probe(path)
        self.assertEqual(hashes, packet_hashes(path))
        self.assertEqual(path.stat().st_mode, stat.st_mode)
        self.assertEqual(path.stat().st_gid, stat.st_gid)
        self.assertEqual(path.stat().st_mtime_ns, stat.st_mtime_ns)
        self.assertNotIn("title", cleanup.tags(after["format"]))
        self.assertNotIn("comment", cleanup.tags(after["format"]))
        streams = after["streams"]
        self.assertEqual([stream["codec_type"] for stream in streams], ["video", "audio", "subtitle", "attachment"])
        for stream in streams:
            self.assertNotIn("title", cleanup.tags(stream))
            self.assertNotIn("comment", cleanup.tags(stream))
        self.assertEqual(cleanup.tags(streams[1])["language"], "ger")
        self.assertNotIn("comment", cleanup.tags(streams[1]))
        for index in (1, 2):
            self.assertEqual(streams[index]["disposition"], before["streams"][index]["disposition"])
        self.assertEqual(cleanup.tags(streams[3])["filename"], "subtitle.ttf")
        self.assertEqual(streams[3]["extradata_size"], len((self.root / "subtitle.ttf").read_bytes()))
        self.assertEqual(cleanup.tags(after["chapters"][0]), {"title": "Opening"})
        self.assertAlmostEqual(float(after["chapters"][0]["end_time"]), 1)
        self.assertFalse(list(self.root.glob(".media-cleanup-*")))

    def test_mp4_removes_attached_picture(self):
        cover = self.root / "cover.png"
        ffmpeg("-f", "lavfi", "-i", "color=c=red:s=32x32", "-frames:v", "1", cover)
        path = self.root / "Movie.mp4"
        ffmpeg(
            "-f", "lavfi", "-i", "testsrc2=s=320x180:r=10:d=1", "-i", cover,
            "-map", "0:v", "-map", "1:v", "-c:v:0", "libx264", "-c:v:1", "copy",
            "-disposition:v:1", "attached_pic", "-metadata", "title=Release spam",
            "-metadata:s:v:0", "title=Custom video label",
            "-metadata:s:v:0", "handler_name=Custom video handler", path,
        )
        hashes = packet_hashes(path)[0]
        cleanup.clean(path)
        self.assertEqual(packet_hashes(path), [hashes])
        streams = cleanup.probe(path)["streams"]
        self.assertEqual(len(streams), 1)
        self.assertNotIn("title", cleanup.tags(streams[0]))
        self.assertNotIn("Custom", cleanup.tags(streams[0]).get("handler_name", ""))

    def test_language_filter_preserves_retained_packets_and_flags(self):
        subtitles = self.root / "captions.srt"
        subtitles.write_text("1\n00:00:00,000 --> 00:00:01,000\nA subtitle.\n")
        path = self.root / "Multilingual.mkv"
        audio_languages = ["jpn", "ger", "eng", "fra", "spa", "und"]
        subtitle_languages = ["jpn", "deu", "eng", "ita", "und"]
        args = [
            "-f", "lavfi", "-i", "testsrc2=s=320x180:r=10:d=1",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
            "-i", subtitles, "-map", "0:v",
        ]
        for _ in audio_languages:
            args.extend(("-map", "1:a"))
        for _ in subtitle_languages:
            args.extend(("-map", "2:s"))
        args.extend(("-c:v", "libx264", "-c:a", "aac", "-c:s", "srt"))
        for index, language in enumerate(audio_languages):
            args.extend((f"-metadata:s:a:{index}", f"language={language}"))
        for index, language in enumerate(subtitle_languages):
            args.extend((f"-metadata:s:s:{index}", f"language={language}"))
        args.extend(("-disposition:a:1", "comment", "-disposition:s:0", "forced",
                     "-disposition:s:1", "hearing_impaired"))
        ffmpeg(*args, path)
        before = cleanup.probe(path)
        hashes = packet_hashes(path)
        cleanup.clean(path)
        streams = cleanup.probe(path)["streams"]
        self.assertEqual(hashes, packet_hashes(path))
        self.assertEqual([cleanup.tags(s).get("language", "und") for s in streams if s["codec_type"] == "audio"],
                         ["jpn", "ger", "eng", "und"])
        self.assertEqual([cleanup.tags(s).get("language", "und") for s in streams if s["codec_type"] == "subtitle"],
                         ["jpn", "deu", "eng", "und"])
        retained = [s for s in before["streams"] if cleanup.keep_stream(s)]
        self.assertEqual([s["disposition"] for s in streams], [s["disposition"] for s in retained])
        self.assertFalse(list(self.root.glob(".media-cleanup-*")))

    def test_language_aliases_and_missing_tags(self):
        for kind in ("audio", "subtitle"):
            for language in ("ja", "JPN", "de", "ger", "DEU", "en", "eng", "en-US", "de_DE", "und", "unknown", ""):
                with self.subTest(kind=kind, language=language):
                    self.assertTrue(cleanup.keep_stream({"codec_type": kind, "tags": {"language": language}}))
            self.assertTrue(cleanup.keep_stream({"codec_type": kind}))
            for language in ("fra", "spa", "ita", "ara", "fr-FR"):
                with self.subTest(kind=kind, language=language):
                    self.assertFalse(cleanup.keep_stream({"codec_type": kind, "tags": {"language": language}}))

    def test_failed_remux_keeps_original_and_removes_temporary(self):
        path = self.root / "unsupported-tracks.mp4"
        shutil.copyfile(self.fixture(), path)
        original = path.read_bytes()
        with self.assertRaises(subprocess.CalledProcessError):
            cleanup.clean(path)
        self.assertEqual(path.read_bytes(), original)
        self.assertFalse(list(self.root.glob(".media-cleanup-*")))

    def test_arr_events(self):
        self.assertEqual(cleanup.event_paths({"Radarr_EventType": "Test"}), [])
        self.assertEqual(cleanup.event_paths({"sonarr_eventtype": "Grab"}), [])
        self.assertEqual(cleanup.event_paths({
            "radarr_eventtype": "Download", "radarr_moviefile_path": "/movies/A | B.mkv",
        }), [Path("/movies/A | B.mkv")])
        self.assertEqual(cleanup.event_paths({
            "sonarr_eventtype": "Download", "sonarr_episodefile_paths": "/shows/A.mkv|/shows/B.mkv",
        }), [Path("/shows/A.mkv"), Path("/shows/B.mkv")])


class FakeArr:
    def __init__(self):
        self.notifications = []
        self.mappings = [
            {"id": 1, "remotePath": "/downloads/complete/radarr/", "localPath": "/downloads/converted/radarr/"},
            {"id": 2, "remotePath": "/other/", "localPath": "/downloads/converted/radarr/"},
        ]
        self.settings = {"enableCompletedDownloadHandling": False, "unrelatedSetting": "keep"}
        self.writes = []

    def request(self, endpoint, data=None, method=None):
        if method:
            self.writes.append((method, endpoint))
        if endpoint == "notification/schema":
            return [{"implementation": "CustomScript", "onDownload": False, "onUpgrade": False,
                     "onImportComplete": False, "onGrab": False, "fields": [{"name": "path"}, {"name": "arguments"}]}]
        if endpoint == "notification":
            if method == "POST":
                self.notifications.append(data | {"id": 1})
            return copy.deepcopy(self.notifications)
        if endpoint == "remotepathmapping":
            return copy.deepcopy(self.mappings)
        if endpoint.startswith("remotepathmapping/") and method == "DELETE":
            self.mappings = [item for item in self.mappings if item["id"] != int(endpoint.split("/")[1])]
            return None
        if endpoint == "config/downloadclient":
            if method == "PUT":
                self.settings = data
            return copy.deepcopy(self.settings)
        raise AssertionError(f"unexpected request: {method} {endpoint}")


class Provisioning(unittest.TestCase):
    def test_only_anvil_mapping_changes_and_repeated_setup_is_idle(self):
        api = FakeArr()
        configure.configure(api, "radarr", "/downloads/", "/bin/clean-media-import")
        self.assertEqual([mapping["id"] for mapping in api.mappings], [2])
        self.assertEqual(api.settings, {"enableCompletedDownloadHandling": True, "unrelatedSetting": "keep"})
        hook = api.notifications[0]
        self.assertTrue(hook["onDownload"] and hook["onUpgrade"])
        self.assertFalse(hook["onImportComplete"] or hook["onGrab"])
        self.assertEqual(api.writes[0], ("POST", "notification"))
        writes = api.writes.copy()
        configure.configure(api, "radarr", "/downloads/", "/bin/clean-media-import")
        self.assertEqual(api.writes, writes)


if __name__ == "__main__":
    unittest.main()

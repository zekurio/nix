"""Check that cleanup keeps skipped audio, changed files, and unknown files."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('cleanup', Path(__file__).with_name('clean-import-leftovers.py'))
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


class CleanupTest(unittest.TestCase):
    def test_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ['imported', 'skipped', 'partial', 'unknown', 'changed', 'linked']:
                folder = root / name
                folder.mkdir()
                (folder / 'song.flac').write_bytes(b'audio')
                (folder / 'cover.jpg').write_bytes(b'cover')
            (root / 'linked' / 'external.jpg').symlink_to(root / 'skipped' / 'cover.jpg')
            records = cleanup.record([root])
            for name in ['imported', 'partial', 'unknown', 'changed', 'linked']:
                (root / name / 'song.flac').unlink()
            (root / 'partial' / 'track.PARTIAL').write_bytes(b'pending')
            (root / 'unknown' / 'notes.pdf').write_bytes(b'keep')
            (root / 'changed' / 'cover.jpg').write_bytes(b'new cover')
            cleanup.clean(records)
            self.assertFalse((root / 'imported').exists())
            for name in ['skipped', 'partial', 'unknown', 'changed', 'linked']:
                self.assertTrue((root / name / 'cover.jpg').exists())
            self.assertTrue((root / 'skipped' / 'song.flac').exists())
            empty = root / 'empty' / 'nested'
            empty.mkdir(parents=True)
            cleanup.prune([root])
            self.assertFalse(empty.parent.exists())
            self.assertTrue(root.is_dir())


if __name__ == '__main__':
    unittest.main()

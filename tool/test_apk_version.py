import tempfile
import unittest
from pathlib import Path
from next_apk_version import next_version, write_version


class ApkVersionTests(unittest.TestCase):
    def test_patch_and_carry(self):
        self.assertEqual(next_version(35, '0.3.5+46', '0.3.5+46'), '0.3.6+47')
        self.assertEqual(next_version(39, '0.3.9+50', '0.3.9+50'), '0.4.0+51')
        self.assertEqual(next_version(99, '0.9.9+60', '0.9.9+60'), '1.0.0+61')

    def test_normalizes_old_numbering_and_preserves_android_floor(self):
        self.assertEqual(next_version(34, '0.3.5+46', '5.10.4+44'), '0.3.5+46')

    def test_failed_build_retry_keeps_same_visible_version(self):
        self.assertEqual(next_version(35, '0.3.6+47', '0.3.5+46'), '0.3.6+47')

    def test_updates_source_and_badge_together(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'pubspec.yaml').write_text('name: test\nversion: 5.12.0+46\n',encoding='utf-8')
            (root/'README.md').write_text('badge/Android-5.12.0-green',encoding='utf-8')
            write_version('0.3.5+46',root)
            self.assertIn('version: 0.3.5+46', (root/'pubspec.yaml').read_text())
            self.assertIn('Android-0.3.5-green', (root/'README.md').read_text())

    def test_rejects_invalid_release_name(self):
        with self.assertRaises(ValueError):
            next_version(-1, '0.3.5+46', '0.3.4+45')

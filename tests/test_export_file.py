import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('export_file', Path(__file__).resolve().parents[1] / 'plugin/helper/export_file.py')
export_file = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export_file)


class SaveExportTests(unittest.TestCase):
    def test_save_preserves_unicode_spaces_and_private_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'stage.md'
            source.write_text('# Export\n\nSome text')
            target = Path(directory) / "My chat's țest.md"
            with patch.object(export_file.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, bytes(target) + b'\n')) as run:
                result = export_file.save(source, str(target))
            self.assertEqual(result['path'], str(target))
            self.assertEqual(target.read_text(), source.read_text())
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            self.assertIn('--confirm-overwrite', run.call_args.args[0])
            self.assertFalse(list(Path(directory).glob('.agent-chat-*')))

    def test_cancel_keeps_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'existing.md'
            target.write_text('keep')
            with patch.object(export_file.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, b'')):
                self.assertEqual(export_file.save('/not-read', str(target)), {'cancelled': True})
            self.assertEqual(target.read_text(), 'keep')

    def test_confirmed_replace_does_not_follow_target_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            source, original, target = (Path(directory) / x for x in ['source.md', 'original.md', 'link.md'])
            source.write_text('export')
            original.write_text('keep')
            target.symlink_to(original)
            with patch.object(export_file.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, bytes(target) + b'\n')):
                export_file.save(source, str(target))
            self.assertFalse(target.is_symlink())
            self.assertEqual(target.read_text(), 'export')
            self.assertEqual(original.read_text(), 'keep')

    def test_failure_is_visible(self):
        with patch.object(export_file.subprocess, 'run', return_value=subprocess.CompletedProcess([], 255, b'')):
            with self.assertRaisesRegex(ValueError, 'Save As'):
                export_file.save('/not-read', '/tmp/export.md')

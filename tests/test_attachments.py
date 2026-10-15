import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('attachments', Path(__file__).resolve().parents[1] / 'plugin/helper/attachments.py')
attachments = importlib.util.module_from_spec(spec)
spec.loader.exec_module(attachments)


class AttachmentTests(unittest.TestCase):
    def test_picker_cancel_is_not_an_error(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(attachments.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, b'', b'')):
            self.assertEqual(attachments.capture('pick', directory), {'cancelled': True})

    def test_picker_failure_is_not_silently_cancelled(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(attachments.subprocess, 'run', return_value=subprocess.CompletedProcess([], 255, b'', b'failed')):
            with self.assertRaisesRegex(ValueError, 'File picker could not open'):
                attachments.capture('pick', directory)

    def test_selection_is_copied_privately_and_survives_source_removal(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'a file.txt'
            source.write_text('attachment')
            result = subprocess.CompletedProcess([], 0, bytes(source) + b'\n', b'')
            with patch.object(attachments.subprocess, 'run', return_value=result):
                selected = attachments.capture('pick', Path(directory) / 'cache')
            source.unlink()
            cached = Path(selected['path'])
            self.assertEqual(cached.read_text(), 'attachment')
            self.assertEqual(cached.stat().st_mode & 0o777, 0o600)
            self.assertEqual(selected['name'], 'a file.txt')

class ScreenshotTests(unittest.TestCase):
    def test_native_capture_copies_only_new_image(self):
        overlay = {'monitor': {'levels': {'3': [{'namespace': 'noctalia-screenshot-region'}]}}}
        times = iter([0, 0, 1, 3])
        with patch.object(attachments, 'clipboard_png', side_effect=[b'old', b'new']), patch.object(attachments.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)), patch.object(attachments.subprocess, 'check_output', side_effect=[json_bytes(overlay), b'{}', b'{}']), patch.object(attachments.time, 'monotonic', side_effect=lambda: next(times)), patch.object(attachments.time, 'sleep'):
            self.assertEqual(attachments.screenshot_png(), b'new')

    def test_overlay_recognizes_annotation_and_ignores_other_surfaces(self):
        self.assertTrue(attachments.capture_overlay_active([{'namespace': 'noctalia-annotate'}]))
        self.assertFalse(attachments.capture_overlay_active([{'namespace': 'noctalia-wallpaper'}]))

    def test_cancel_does_not_attach_old_clipboard(self):
        times = iter([0, 0, 1, 3])
        with patch.object(attachments, 'clipboard_png', return_value=b'old'), patch.object(attachments.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)), patch.object(attachments.subprocess, 'check_output', side_effect=[json_bytes([{'namespace': 'noctalia-screenshot-region'}]), b'{}', b'{}']), patch.object(attachments.time, 'monotonic', side_effect=lambda: next(times)), patch.object(attachments.time, 'sleep'):
            self.assertIsNone(attachments.screenshot_png())


def json_bytes(value):
    import json
    return json.dumps(value).encode()

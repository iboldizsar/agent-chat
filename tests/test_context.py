import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('context_helper', ROOT / 'plugin/helper/context.py')
context = importlib.util.module_from_spec(spec)
spec.loader.exec_module(context)


class ContextTests(unittest.TestCase):
    def test_fresh_store_payload_creates_private_context_once(self):
        with tempfile.TemporaryDirectory() as home:
            target = Path(home) / '.local/share/agent-chat/assistant'
            result = context.ensure(target, home=home)
            self.assertTrue(result['created'])
            file = target / 'AGENTS.md'
            self.assertEqual(file.stat().st_mode & 0o777, 0o600)
            file.write_text('User customization')
            os.chmod(file, 0o640)
            self.assertEqual(context.ensure(target, home=home), {'ready': True, 'created': False})
            self.assertEqual(file.read_text(), 'User customization')
            self.assertEqual(file.stat().st_mode & 0o777, 0o640)
            self.assertFalse(list(target.glob('.agent-chat-context-*')))

    def test_custom_missing_or_broken_symlink_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as home:
            target = Path(home) / 'custom'
            self.assertIn('error', context.ensure(target, home=home))
            self.assertFalse(target.exists())
            target.mkdir()
            (target / 'AGENTS.md').symlink_to(target / 'missing')
            self.assertIn('error', context.ensure(target, home=home))
            self.assertTrue((target / 'AGENTS.md').is_symlink())

    def test_concurrent_existing_file_survives_and_staging_is_removed(self):
        with tempfile.TemporaryDirectory() as home:
            target = Path(home) / '.local/share/agent-chat/assistant'
            def concurrent_write(source, destination):
                Path(destination).write_text('Concurrent instructions')
                raise FileExistsError()
            with patch.object(context.os, 'link', side_effect=concurrent_write):
                self.assertFalse(context.ensure(target, home=home)['created'])
            self.assertEqual((target / 'AGENTS.md').read_text(), 'Concurrent instructions')
            self.assertFalse(list(target.glob('.agent-chat-context-*')))

    def test_failed_publish_leaves_no_partial_context(self):
        with tempfile.TemporaryDirectory() as home:
            target = Path(home) / '.local/share/agent-chat/assistant'
            with patch.object(context.os, 'link', side_effect=OSError('failure')), self.assertRaises(OSError):
                context.ensure(target, home=home)
            self.assertFalse((target / 'AGENTS.md').exists())
            self.assertFalse(list(target.glob('.agent-chat-context-*')))

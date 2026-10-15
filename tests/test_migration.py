import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('migration', ROOT / 'scripts/migrate.py')
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.source, self.target = migration.paths(self.home)
        self.source.mkdir(parents=True)
        (self.source / 'preferences.json').write_text('{"drafts":{"old":"private draft"},"modelChoices":{}}')
        (self.source / 'attachments').mkdir()
        (self.source / 'attachments/image.png').write_bytes(b'retained original')

    def test_preview_never_creates_target(self):
        report = migration.migrate(self.home)
        self.assertFalse(report['applied'])
        self.assertFalse(self.target.exists())

    def test_copy_preserves_source_and_private_permissions(self):
        self.assertTrue(migration.migrate(self.home, apply=True)['applied'])
        self.assertEqual((self.target / 'preferences.json').read_bytes(), (self.source / 'preferences.json').read_bytes())
        self.assertEqual((self.target / 'preferences.json').stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.target / 'attachments/image.png').read_bytes(), b'retained original')
        self.assertTrue((self.source / 'attachments/image.png').exists())
        with self.assertRaises(ValueError):
            migration.migrate(self.home, apply=True)

    def test_pending_writes_and_symlinks_are_refused(self):
        pending = self.source / 'preferences.json.writing'
        pending.write_text('keep pending')
        with self.assertRaises(ValueError):
            migration.migrate(self.home, apply=True)
        pending.unlink()
        (self.source / 'linked').symlink_to(self.source / 'preferences.json')
        with self.assertRaises(ValueError):
            migration.migrate(self.home, apply=True)
        self.assertFalse(self.target.exists())

    def test_concurrent_write_aborts_without_changing_old_state(self):
        original_copy = migration.shutil.copytree
        def changing_copy(source, target, *args, **kwargs):
            result = original_copy(source, target, *args, **kwargs)
            (self.source / 'preferences.json').write_text('new draft')
            return result
        with patch.object(migration.shutil, 'copytree', side_effect=changing_copy), self.assertRaises(ValueError):
            migration.migrate(self.home, apply=True)
        self.assertEqual((self.source / 'preferences.json').read_text(), 'new draft')
        self.assertFalse(self.target.exists())
        self.assertFalse(self.target.with_name('agent-chat.migrating').exists())

    def test_target_created_concurrently_is_never_overwritten(self):
        original_snapshot = migration.snapshot
        calls = 0
        def concurrent_target(folder):
            nonlocal calls
            value = original_snapshot(folder)
            calls += 1
            if calls == 2:
                self.target.mkdir()
                (self.target / 'keep').write_text('new installation')
            return value
        with patch.object(migration, 'snapshot', side_effect=concurrent_target), self.assertRaises(FileExistsError):
            migration.migrate(self.home, apply=True)
        self.assertEqual((self.target / 'keep').read_text(), 'new installation')

    def test_settings_copy_preserves_comments_other_plugins_and_old_cache_paths(self):
        settings = self.home / 'settings.toml'
        original = '''# user customization
[plugins]
enabled = ["local/agent-chat", "other/plugin"]
[plugin_settings."local/agent-chat"]
assistant_dir = "/my/context"
retained_path = "/state/local/agent-chat/attachments/image.png"
[widget.agent_chat]
type = "local/agent-chat:status"
'''
        settings.write_text(original)
        self.assertEqual(migration.settings_copy(settings)['replacements'], 3)
        self.assertEqual(settings.read_text(), original)
        backup = self.home / 'backup'
        migration.settings_copy(settings, backup, apply=True)
        self.assertEqual((backup / 'noctalia-settings.toml').read_text(), original)
        updated = settings.read_text()
        self.assertIn('# user customization', updated)
        self.assertIn('"other/plugin"', updated)
        self.assertIn('"iboldizsar/agent-chat:status"', updated)
        self.assertIn('/state/local/agent-chat/attachments/image.png', updated)
        self.assertFalse(migration.settings_copy(settings, backup, apply=True)['applied'])

    def test_conflicting_public_settings_are_not_overwritten(self):
        settings = self.home / 'settings.toml'
        original = '[plugin_settings."local/agent-chat"]\nx=1\n[plugin_settings."iboldizsar/agent-chat"]\nx=2\n'
        settings.write_text(original)
        with self.assertRaises(ValueError):
            migration.settings_copy(settings, self.home / 'backup', apply=True)
        self.assertEqual(settings.read_text(), original)

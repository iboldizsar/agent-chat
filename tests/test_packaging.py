import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


installer = module('installer', 'install.py')
packager = module('packager', 'package.py')
doctor = module('doctor', 'doctor.py')
community = module('community', 'community.py')


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'a different home'
        self.destination = self.home / '.local/share/noctalia/plugins/agent-chat'
        self.context = self.home / '.local/share/agent-chat/assistant/AGENTS.md'
        self.state = self.home / '.local/state/noctalia/plugins/data/local/agent-chat/preferences.json'

    def install(self, **kwargs):
        with contextlib.redirect_stdout(io.StringIO()):
            installer.install(self.home, **kwargs)

    def test_preview_does_not_create_home(self):
        self.install()
        self.assertFalse(self.home.exists())

    def test_install_update_uninstall_preserve_user_state(self):
        self.install(apply=True)
        self.assertEqual(self.context.stat().st_mode & 0o777, 0o600)
        self.assertIn('particular username', self.context.read_text())
        self.context.write_text('Custom laptop instructions')
        self.state.parent.mkdir(parents=True)
        self.state.write_text('private state')
        (self.destination / 'obsolete.txt').write_text('old payload')
        self.install(apply=True)
        self.assertFalse((self.destination / 'obsolete.txt').exists())
        self.assertEqual(self.context.read_text(), 'Custom laptop instructions')
        backups = list((self.home / '.local/state/agent-chat/install-backups').glob('*/plugin/obsolete.txt'))
        self.assertEqual(len(backups), 1)
        marker = json.loads((self.destination / '.agent-chat-source.json').read_text())
        self.assertEqual(marker['version'], installer.manifest()['version'])
        self.install(apply=True, uninstall=True)
        self.assertFalse(self.destination.exists())
        self.assertEqual(self.state.read_text(), 'private state')
        self.assertEqual(self.context.read_text(), 'Custom laptop instructions')

    def test_foreign_directory_and_symlinks_refused(self):
        self.destination.mkdir(parents=True)
        (self.destination / 'keep').write_text('keep')
        with self.assertRaises(SystemExit):
            self.install(apply=True)
        self.assertEqual((self.destination / 'keep').read_text(), 'keep')
        shutil.rmtree(self.destination)
        other = self.home / 'other'
        other.mkdir()
        self.destination.symlink_to(other)
        with self.assertRaises(SystemExit):
            self.install(apply=True, uninstall=True)
        self.assertTrue(other.is_dir())

    def test_failed_upgrade_restores_previous_payload(self):
        self.install(apply=True)
        (self.destination / 'old.txt').write_text('keep')
        rename = Path.rename
        def fail_new_payload(path, target):
            if path.name == 'agent-chat.installing':
                raise OSError('simulated rename failure')
            return rename(path, target)
        with patch.object(Path, 'rename', fail_new_payload), self.assertRaises(OSError):
            self.install(apply=True)
        self.assertEqual((self.destination / 'old.txt').read_text(), 'keep')
        self.assertFalse(self.destination.with_name('agent-chat.installing').exists())

    def test_archive_is_reproducible_allowlisted_and_installable(self):
        with contextlib.redirect_stdout(io.StringIO()):
            archive = packager.build(Path(self.temp.name) / 'release')
            first = archive.read_bytes()
            packager.build(archive.parent)
        self.assertEqual(archive.read_bytes(), first)
        checksum = archive.with_suffix('.gz.sha256').read_text().split()[0]
        self.assertEqual(hashlib.sha256(first).hexdigest(), checksum)
        allowed = {line.strip() for line in (ROOT / 'PACKAGE-FILES.txt').read_text().splitlines() if line.strip() and not line.startswith('#')}
        with tarfile.open(archive) as data:
            members = data.getmembers()
            self.assertEqual({'/'.join(x.name.split('/')[1:]) for x in members}, allowed)
            self.assertTrue(all(x.isfile() for x in members))
            unpacked = Path(self.temp.name) / 'unpacked'
            data.extractall(unpacked, filter='data')
        release = next(unpacked.iterdir())
        with patch.object(installer, 'ROOT', release):
            self.install(apply=True)
        self.assertTrue((self.destination / 'service.luau').is_file())
        self.assertFalse((release / 'CHAT-CONTEXT.md').exists())
        self.assertFalse((release / 'docs/IMPLEMENTATION.md').exists())

    def test_doctor_reports_missing_required_dependencies_without_starting_backends(self):
        with patch.object(doctor.shutil, 'which', return_value=None), contextlib.redirect_stdout(io.StringIO()):
            self.assertFalse(doctor.check())
        with patch.object(doctor.shutil, 'which', side_effect=lambda name: name if name in ('noctalia', 'codex') else None), patch.object(doctor, 'version', side_effect=lambda name: 'noctalia v5.2.1' if name == 'noctalia' else 'codex-cli 0.162.1'), contextlib.redirect_stdout(io.StringIO()):
            self.assertTrue(doctor.check('codex'))
            self.assertFalse(doctor.check('opencode'))

    def test_doctor_rejects_unsupported_opencode_v1(self):
        with patch.object(doctor.shutil, 'which', side_effect=lambda name: name if name in ('noctalia', 'opencode') else None), patch.object(doctor, 'version', side_effect=lambda name: 'noctalia v5.2.1' if name == 'noctalia' else 'opencode v1.19.0'), contextlib.redirect_stdout(io.StringIO()):
            self.assertFalse(doctor.check('opencode'))


class CommunityStagingTests(unittest.TestCase):
    def test_staging_is_self_contained_and_rewrites_identity_only_in_output(self):
        with tempfile.TemporaryDirectory() as directory:
            target = community.stage(Path(directory) / 'review')
            metadata = installer.tomllib.loads((target / 'plugin.toml').read_text())
            self.assertEqual(metadata['id'], 'iboldizsar/agent-chat')
            self.assertEqual(metadata['author'], 'iboldizsar')
            self.assertEqual(metadata['plugin_api'], 33)
            self.assertIn('iboldizsar/agent-chat:fullscreen', (target / 'README.md').read_text())
            self.assertNotIn('local/agent-chat', (target / 'service.luau').read_text())
            self.assertTrue((target / 'assets/assistant-AGENTS.md').is_file())
            self.assertTrue((target / 'helper/context.py').is_file())
            self.assertFalse((target / 'preferences.json').exists())
            self.assertEqual(installer.manifest()['id'], 'local/agent-chat')
            self.assertEqual(community.blockers(target), ['Missing 960x540 thumbnail.webp from a real screenshot'])
            with self.assertRaises(ValueError):
                community.stage(Path(directory) / 'review')

    def test_bad_identity_or_incompatible_api_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            for author, api in [('Bad/Name', 33), ('valid', 26)]:
                with self.assertRaises(ValueError):
                    community.stage(directory, author, api)
            self.assertFalse((Path(directory) / 'agent-chat').exists())

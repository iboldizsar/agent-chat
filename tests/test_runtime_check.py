import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('runtime_check', Path(__file__).resolve().parents[1] / 'plugin/helper/runtime_check.py')
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class RuntimeCheckTests(unittest.TestCase):
    def test_missing_backend_never_runs_a_command(self):
        with patch.object(runtime.shutil, 'which', return_value=None), patch.object(runtime.subprocess, 'run') as run:
            self.assertEqual(runtime.backend('codex'), {'status': 'missing'})
            run.assert_not_called()

    def test_versions_are_bounded_sanitized_and_checked(self):
        for name, version, status in [('opencode', '2.0.29', 'available'), ('opencode', '1.19.0', 'unsupported'),
                                      ('codex', '0.162.1', 'available'), ('codex', '0.100.0', 'unsupported')]:
            with self.subTest(name=name, version=version), patch.object(runtime.shutil, 'which', return_value='/bin/tool'), patch.object(runtime.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'tool ' + version + ' private data', '')) as run:
                self.assertEqual(runtime.backend(name), {'status': status, 'version': version})
                self.assertEqual(run.call_args.args[0], [name, '--version'])
                self.assertEqual(run.call_args.kwargs['timeout'], 2)

    def test_failed_unknown_and_timed_out_versions_are_unverified(self):
        for outcome in [subprocess.CompletedProcess([], 1, '0.162.1', ''), subprocess.CompletedProcess([], 0, 'unknown private data', ''), subprocess.TimeoutExpired('tool', 2)]:
            with patch.object(runtime.shutil, 'which', return_value='/bin/tool'), patch.object(runtime.subprocess, 'run') as run:
                if isinstance(outcome, Exception):
                    run.side_effect = outcome
                else:
                    run.return_value = outcome
                self.assertEqual(runtime.backend('codex'), {'status': 'unverified'})

    def test_single_backend_and_missing_optional_tools(self):
        with patch.object(runtime.shutil, 'which', side_effect=lambda name: '/bin/codex' if name == 'codex' else None), patch.object(runtime.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'codex-cli 0.162.1', '')):
            result = runtime.check()
        self.assertEqual(result['backends']['codex']['status'], 'available')
        self.assertEqual(result['backends']['opencode']['status'], 'missing')
        self.assertFalse(any(result['tools'].values()))

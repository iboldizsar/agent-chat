import json
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'plugin/helper/interactive_job.py'


class InteractiveJobTests(unittest.TestCase):
    def invoke(self, code):
        result = subprocess.run([sys.executable, str(HELPER), sys.executable, '-c', code], capture_output=True, text=True, timeout=8)
        self.assertEqual(result.returncode, 0)
        return result.stdout.splitlines()

    def test_success_cancel_and_errors_always_have_one_result(self):
        self.assertEqual(json.loads(self.invoke('print(\'{"cancelled":true}\')')[-1]), {'cancelled': True})
        for code in ['pass', 'raise SystemExit(9)', 'print("not json")', 'print("[]")', 'print("one\\ntwo")']:
            with self.subTest(code=code):
                self.assertIn('error', json.loads(self.invoke(code)[-1]))

    def test_dialog_liveness_does_not_impose_a_user_deadline(self):
        lines = self.invoke('import time; time.sleep(2.2); print(\'{"path":"/tmp/chosen"}\')')
        self.assertIn('@agent-chat:alive', lines)
        self.assertEqual(json.loads(lines[-1])['path'], '/tmp/chosen')

    def test_teardown_terminates_the_owned_child(self):
        with tempfile.TemporaryDirectory() as directory:
            pidfile = Path(directory) / 'child.pid'
            code = 'import os,time; from pathlib import Path; Path(' + repr(str(pidfile)) + ').write_text(str(os.getpid())); time.sleep(60)'
            process = subprocess.Popen([sys.executable, str(HELPER), sys.executable, '-c', code], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                deadline = time.monotonic() + 5
                while not pidfile.exists() and time.monotonic() < deadline:
                    time.sleep(.01)
                self.assertTrue(pidfile.exists())
                child = int(pidfile.read_text())
                process.send_signal(signal.SIGTERM)
                stdout, _ = process.communicate(timeout=5)
                self.assertIn('error', json.loads(stdout.splitlines()[-1]))
                with self.assertRaises(ProcessLookupError):
                    import os
                    os.kill(child, 0)
            finally:
                if process.poll() is None:
                    process.kill(); process.communicate()

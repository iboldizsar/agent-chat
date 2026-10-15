import importlib.util
import json
from pathlib import Path
import sys
import threading
import time
import unittest
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bridge', ROOT / 'plugin/helper/codex_bridge.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class TransportTests(unittest.TestCase):
    def setUp(self):
        self.peer = bridge.Codex('/tmp', [sys.executable, str(ROOT / 'tests/fake_codex.py')])

    def tearDown(self):
        self.peer.close()

    def test_concurrent_requests_correlate_and_do_not_replay(self):
        self.peer.start()
        results = {}
        def run(i):
            results[i] = self.peer.call('echo', {'value': i})
        workers = [threading.Thread(target=run, args=(i,)) for i in range(12)]
        for worker in workers:
            worker.start()
        for worker in workers:
            worker.join(timeout=3)
        self.assertEqual(results, {i: {'value': i} for i in range(12)})

    def test_scope_rejects_unrelated_threads(self):
        with self.assertRaisesRegex(bridge.BridgeError, 'outside'):
            self.peer.request('thread/resume', {'threadId': 'unrelated'})

    def test_pending_request_survives_ui_disconnect_until_reply(self):
        tid = self.peer.request('thread/start', {})['thread']['id']
        self.peer.request('turn/start', {'threadId': tid, 'input': []})
        deadline = time.monotonic() + 2
        while not self.peer.pending and time.monotonic() < deadline:
            time.sleep(.01)
        self.assertIn('100', self.peer.pending)
        self.peer.reply(100, {'decision': 'decline'})
        self.assertNotIn('100', self.peer.pending)
        with self.assertRaises(bridge.BridgeError):
            self.peer.reply(100, {'decision': 'accept'})

    def test_quota_guard_blocks_before_turn_submission(self):
        self.peer.start()
        self.peer.owned.add('thread-1')
        original = self.peer.call
        calls = []
        def call(method, params, **kwargs):
            calls.append(method)
            if method == 'account/rateLimits/read':
                return {'rateLimits': {'primary': {'usedPercent': 85}}}
            return original(method, params, **kwargs)
        self.peer.call = call
        with self.assertRaisesRegex(bridge.BridgeError, 'Paused'):
            self.peer.request('turn/start', {'threadId': 'thread-1', 'input': []})
        self.assertNotIn('turn/start', calls)

    def test_known_quota_block_survives_failed_refresh(self):
        self.peer.owned.add('thread-1')
        self.peer.usage = {'known': True, 'blocked': True, 'windows': []}
        def failed(*args, **kwargs):
            raise bridge.BridgeError('temporary quota outage')
        self.peer.call = failed
        with self.assertRaisesRegex(bridge.BridgeError, 'Paused'):
            self.peer.request('turn/start', {'threadId': 'thread-1', 'input': []})
        self.assertTrue(self.peer.usage['stale'])

    def test_usage_summary_excludes_private_account_metadata(self):
        result = bridge.usage_summary({'accountId': 'private', 'rateLimitResetCredits': 'private',
                  'ordinaryUsageAllowed': False, 'rateLimits': {'primary': {'usedPercent': 20}}})
        self.assertTrue(result['blocked'])
        self.assertNotIn('private', json.dumps(result))


class HttpTests(unittest.TestCase):
    def setUp(self):
        self.peer = bridge.Codex('/tmp', [sys.executable, str(ROOT / 'tests/fake_codex.py')])
        self.server = bridge.Server(self.peer, 'private-test-token')
        self.worker = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.worker.start()
        self.url = 'http://127.0.0.1:' + str(self.server.server_port)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.peer.close()

    def test_private_endpoint_rejects_missing_token_and_browser_origins(self):
        for headers in [{}, {'Authorization': 'Bearer private-test-token', 'Origin': 'http://example.com'}]:
            with self.assertRaises(urllib.error.HTTPError) as error:
                urllib.request.urlopen(urllib.request.Request(self.url + '/health', headers=headers))
            self.assertEqual(error.exception.code, 403)
            error.exception.close()
        req = urllib.request.Request(self.url + '/health', headers={'Authorization': 'Bearer private-test-token'})
        self.assertEqual(json.load(urllib.request.urlopen(req))['version'], 1)

    def test_shutdown_cannot_drop_active_work(self):
        self.peer.active.add('thread-1')
        req = urllib.request.Request(self.url + '/shutdown', data=b'{}',
                 headers={'Authorization': 'Bearer private-test-token', 'Content-Type': 'application/json'})
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(req)
        self.assertEqual(error.exception.code, 400)
        error.exception.close()
        self.assertIn('thread-1', self.peer.active)

    def test_new_helper_resets_stale_event_cursor(self):
        self.peer.emit({'method': 'test', 'params': {}})
        req = urllib.request.Request(self.url + '/events?after=999',
                      headers={'Authorization': 'Bearer private-test-token'})
        with urllib.request.urlopen(req, timeout=2) as response:
            first = response.readline().decode()
            self.assertIn('bridge/resync', first)
            self.assertIn('"seq":0', first)

    def test_transport_retains_request_while_http_clients_change(self):
        def post(method, params):
            req = urllib.request.Request(self.url + '/rpc', data=json.dumps({'method': method, 'params': params}).encode(),
                      headers={'Authorization': 'Bearer private-test-token', 'Content-Type': 'application/json'})
            return json.load(urllib.request.urlopen(req))['result']
        tid = post('thread/start', {})['thread']['id']
        post('turn/start', {'threadId': tid, 'input': []})
        time.sleep(.02)
        req = urllib.request.Request(self.url + '/pending', headers={'Authorization': 'Bearer private-test-token'})
        pending = json.load(urllib.request.urlopen(req))['pending']
        self.assertEqual(pending[0]['id'], 100)


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
"""Private, persistent transport for Codex. No provider keys or transcript database."""
import argparse
import collections
import fcntl
import hmac
import json
import os
from pathlib import Path
import queue
import secrets
import signal
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

MAX_BODY = 8 * 1024 * 1024
PAUSE_AT = 85


class BridgeError(Exception):
    pass


def atomic_json(path, value):
    temp = path.with_suffix('.tmp')
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as out:
        json.dump(value, out)
    os.replace(temp, path)


def usage_summary(result):
    """Never forward account IDs, reset-credit IDs, or other account metadata."""
    limits = result.get('rateLimitsByLimitId') or {'codex': result.get('rateLimits', {})}
    windows = []
    for name, limit in limits.items():
        for kind in ('primary', 'secondary'):
            window = limit.get(kind)
            if window:
                windows.append({'name': name, 'window': kind, **{k: window.get(k) for k in
                                ('usedPercent', 'windowDurationMins', 'resetsAt')}})
    blocked = result.get('ordinaryUsageAllowed') is False or any(
        l.get('spendControlReached') or l.get('rateLimitReachedType') for l in limits.values())
    blocked = bool(blocked or any(w.get('usedPercent', 0) >= PAUSE_AT for w in windows))
    return {'known': bool(windows), 'blocked': blocked, 'pauseAt': PAUSE_AT,
            'windows': windows, 'checkedAt': time.time()}


class Codex:
    def __init__(self, cwd, command=None):
        self.cwd = str(Path(cwd).resolve())
        self.command = command or ['codex', 'app-server', '--stdio']
        self.process = None
        self.lock = threading.RLock()
        self.write_lock = threading.Lock()
        self.start_lock = threading.Lock()
        self.waiters = {}
        self.counter = 0
        self.events = collections.deque(maxlen=512)
        self.condition = threading.Condition()
        self.seq = 0
        self.pending = {}
        self.active = set()
        self.owned = set()
        self.usage = {'known': False, 'blocked': False, 'windows': []}
        self.closed = False
        self.reader = None

    def emit(self, message):
        with self.condition:
            self.seq += 1
            self.events.append((self.seq, message))
            self.condition.notify_all()

    def start(self):
        with self.start_lock:
            if self.closed:
                raise BridgeError('Codex helper is stopping')
            if self.process and self.process.poll() is None:
                return
            if self.reader:
                self.reader.join(timeout=2)
            env = {k: v for k, v in os.environ.items() if not k.startswith('HERDR_')}
            self.process = subprocess.Popen(self.command, stdin=subprocess.PIPE,
                                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                            env=env, cwd=self.cwd)
            self.reader = threading.Thread(target=self.read, args=(self.process,), daemon=True)
            self.reader.start()
            self.call('initialize', {'clientInfo': {'name': 'noctalia_agent_chat',
                      'title': 'Agent Chat', 'version': '0.9.0'}}, start=False)
            self.write({'method': 'initialized'})

    def write(self, value):
        payload = (json.dumps(value, separators=(',', ':')) + '\n').encode()
        with self.write_lock:
            if not self.process or self.process.poll() is not None:
                raise BridgeError('Codex disconnected; prompt was not replayed')
            self.process.stdin.write(payload)
            self.process.stdin.flush()

    def read(self, process):
        try:
            for line in process.stdout:
                if len(line) > 16 * 1024 * 1024:
                    raise BridgeError('Codex message exceeds transport limit')
                value = json.loads(line)
                if 'id' in value and 'method' not in value:
                    with self.lock:
                        waiter = self.waiters.get(value['id'])
                    if waiter:
                        waiter.put(value)
                    continue
                method, params = value.get('method', ''), value.get('params', {})
                if method == 'account/rateLimits/updated':
                    self.usage = usage_summary(params)
                    self.emit({'method': 'bridge/usage', 'params': self.usage})
                    continue
                tid = params.get('threadId') or (params.get('thread') or {}).get('id')
                if tid and tid not in self.owned:
                    continue
                if method == 'turn/started':
                    self.active.add(params.get('threadId'))
                elif method == 'turn/completed':
                    self.active.discard(params.get('threadId'))
                if 'id' in value:
                    self.pending[str(value['id'])] = value
                if method == 'serverRequest/resolved':
                    self.pending.pop(str(params.get('requestId')), None)
                self.emit(value)
        except (OSError, ValueError, BridgeError):
            pass
        finally:
            with self.lock:
                for waiter in self.waiters.values():
                    waiter.put({'error': {'message': 'Codex connection ended; request outcome may be unknown'}})
                self.pending.clear()
                self.active.clear()
            self.emit({'method': 'bridge/disconnected', 'params': {}})

    def call(self, method, params, start=True, timeout=30):
        if start:
            self.start()
        with self.lock:
            self.counter += 1
            ident = self.counter
            waiter = queue.Queue()
            self.waiters[ident] = waiter
        try:
            self.write({'id': ident, 'method': method, 'params': params})
            try:
                response = waiter.get(timeout=timeout)
            except queue.Empty:
                raise BridgeError('Codex request timed out; do not resend automatically') from None
            if 'error' in response:
                raise BridgeError(response['error'].get('message', 'Codex request failed'))
            return response['result']
        finally:
            with self.lock:
                self.waiters.pop(ident, None)

    def check_thread(self, ident):
        if ident not in self.owned:
            thread = self.call('thread/read', {'threadId': ident, 'includeTurns': False})['thread']
            if str(Path(thread.get('cwd', '')).resolve()) != self.cwd:
                raise BridgeError('Conversation is outside the assistant directory')
            self.owned.add(ident)

    def request(self, method, params):
        allowed = {'model/list', 'skills/list', 'account/read', 'account/rateLimits/read',
                   'thread/start', 'thread/resume', 'thread/list', 'thread/read',
                   'thread/turns/list', 'thread/items/list', 'thread/name/set',
                   'thread/delete', 'turn/start', 'turn/interrupt'}
        if method not in allowed:
            raise BridgeError('Unsupported Codex operation')
        params = dict(params)
        if method == 'account/read':
            r = self.call(method, {'refreshToken': False})
            return {'signedIn': r.get('account') is not None,
                    'type': (r.get('account') or {}).get('type')}
        if method == 'account/rateLimits/read':
            self.usage = usage_summary(self.call(method, {}))
            return self.usage
        if method == 'skills/list':
            params = {'cwds': [self.cwd]}
        if method in ('thread/start', 'thread/resume', 'thread/list'):
            params['cwd'] = self.cwd
        if method == 'thread/start':
            # Deliberate defaults for laptop help; never copy an unrestricted alias.
            params.update(approvalPolicy='on-request', sandbox='workspace-write')
        if 'threadId' in params:
            self.check_thread(params['threadId'])
        if method == 'turn/start':
            # Usage is queried before each user turn; no automatic paid/reset fallback.
            try:
                self.usage = usage_summary(self.call('account/rateLimits/read', {}))
            except BridgeError:
                # Preserve a known block through transient quota-read failures.
                self.usage = {**self.usage, 'stale': True}
            if self.usage['blocked']:
                raise BridgeError('Paused near the Codex usage limit. Wait for allowance to reset.')
        if method == 'turn/start':
            # Guard shutdown even before the first turn/started notification arrives.
            self.active.add(params['threadId'])
        result = self.call(method, params)
        if method == 'turn/start' and result.get('turn', {}).get('status') != 'inProgress':
            self.active.discard(params['threadId'])
        if method in ('thread/start', 'thread/resume'):
            self.owned.add(result['thread']['id'])
        if method == 'thread/delete':
            self.owned.discard(params['threadId'])
        return result

    def reply(self, ident, result):
        key = str(ident)
        request = self.pending.get(key)
        if request is None:
            raise BridgeError('Request is no longer pending')
        self.write({'id': request['id'], 'result': result})
        self.pending.pop(key, None)
        return {}

    def close(self):
        self.closed = True
        with self.condition:
            self.condition.notify_all()
        if self.process and self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=5)
        if self.reader:
            self.reader.join(timeout=2)
        if self.process:
            self.process.stdout.close()


class Server(ThreadingHTTPServer):
    daemon_threads = True
    def __init__(self, bridge, token):
        self.bridge, self.token = bridge, token
        super().__init__(('127.0.0.1', 0), Handler)


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass  # Requests can contain private text. Never use the default access logger.

    def authorized(self):
        expected = 'Bearer ' + self.server.token
        host = self.headers.get('Host', '')
        valid = hmac.compare_digest(self.headers.get('Authorization', ''), expected)
        return valid and host == f'127.0.0.1:{self.server.server_port}' and not self.headers.get('Origin')

    def send_json(self, status, value):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if not self.authorized():
            return self.send_json(403, {'error': 'Forbidden'})
        path = urlparse(self.path)
        bridge = self.server.bridge
        if path.path == '/health':
            return self.send_json(200, {'version': 1, 'cwd': bridge.cwd})
        if path.path == '/pending':
            return self.send_json(200, {'pending': list(bridge.pending.values()), 'usage': bridge.usage,
                                        'cursor': bridge.seq})
        if path.path != '/events':
            return self.send_json(404, {'error': 'Unknown route'})
        try:
            cursor = int(parse_qs(path.query).get('after', ['0'])[0])
        except ValueError:
            return self.send_json(400, {'error': 'Invalid event cursor'})
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        try:
            if cursor > bridge.seq:
                self.wfile.write(b'data: {"seq":0,"method":"bridge/resync","params":{}}\n\n')
                self.wfile.flush()
                cursor = 0
            while not bridge.closed:
                with bridge.condition:
                    if not bridge.events or bridge.events[-1][0] <= cursor:
                        bridge.condition.wait(timeout=10)
                    events = list(bridge.events)
                if events and cursor and cursor < events[0][0] - 1:
                    self.wfile.write(b'data: {"method":"bridge/resync","params":{}}\n\n')
                for seq, message in events:
                    if seq > cursor:
                        self.wfile.write(('data: ' + json.dumps({'seq': seq, **message}) + '\n\n').encode())
                        cursor = seq
                self.wfile.write(b': heartbeat\n\n')
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_POST(self):
        if not self.authorized():
            return self.send_json(403, {'error': 'Forbidden'})
        try:
            if self.headers.get('Content-Type', '').split(';')[0] != 'application/json':
                return self.send_json(415, {'error': 'JSON required'})
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= MAX_BODY:
                return self.send_json(413, {'error': 'Request too large or empty'})
            value = json.loads(self.rfile.read(length))
            if self.path == '/rpc':
                result = self.server.bridge.request(value['method'], value.get('params', {}))
            elif self.path == '/reply':
                result = self.server.bridge.reply(value['id'], value['result'])
            elif self.path == '/shutdown':
                if self.server.bridge.active or self.server.bridge.pending:
                    raise BridgeError('Stop active turns and answer pending requests before stopping the helper')
                result = {}
                threading.Thread(target=self.server.shutdown, daemon=True).start()
            else:
                return self.send_json(404, {'error': 'Unknown route'})
            self.send_json(200, {'result': result})
        except (BridgeError, KeyError, TypeError, ValueError, OSError) as error:
            self.send_json(400, {'error': str(error)[:500]})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['serve', 'ensure', 'stop'])
    parser.add_argument('--state-dir', required=True)
    parser.add_argument('--cwd', required=True)
    args = parser.parse_args()
    state = Path(args.state_dir).expanduser().resolve()
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(state, 0o700)
    endpoint = state / 'endpoint.json'
    if args.action == 'stop':
        import urllib.request
        registration = json.loads(endpoint.read_text())
        if registration['cwd'] != str(Path(args.cwd).expanduser().resolve()):
            raise SystemExit('Helper belongs to a different assistant directory')
        req = urllib.request.Request(registration['url'] + '/shutdown', data=b'{}',
            headers={'Authorization': 'Bearer ' + registration['token'], 'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=5) as response:
            json.load(response)
        return
    if args.action == 'ensure':
        subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'serve',
                          '--state-dir', str(state), '--cwd', str(Path(args.cwd).expanduser())],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        return
    lock = open(state / 'helper.lock', 'a')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return
    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.is_dir():
        raise SystemExit('Assistant directory does not exist')
    os.umask(0o077)
    bridge = Codex(cwd)
    server = Server(bridge, secrets.token_urlsafe(32))
    atomic_json(endpoint, {'url': f'http://127.0.0.1:{server.server_port}',
                          'token': server.token, 'pid': os.getpid(), 'cwd': str(cwd)})
    def stop(*_):
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        server.serve_forever()
    finally:
        bridge.close()
        server.server_close()
        endpoint.unlink(missing_ok=True)


if __name__ == '__main__':
    main()

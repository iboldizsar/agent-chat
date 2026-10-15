"""Deterministic app-server peer. Never calls a provider."""
import json
import sys


def send(value):
    print(json.dumps(value), flush=True)


for line in sys.stdin:
    m = json.loads(line)
    method, params = m.get('method'), m.get('params', {})
    if 'id' not in m or not method:
        continue
    if method == 'turn/start':
        result = {'turn': {'id': 'turn-1', 'status': 'inProgress'}}
    elif method == 'account/rateLimits/read':
        result = {'ordinaryUsageAllowed': True, 'rateLimits': {'primary': {'usedPercent': 10, 'windowDurationMins': 300}}}
    elif method == 'thread/read':
        result = {'thread': {'id': params['threadId'], 'cwd': '/unrelated'}}
    elif method == 'thread/start':
        result = {'thread': {'id': 'thread-1', 'cwd': params['cwd']}}
    elif method == 'echo':
        result = params
    else:
        result = {}
    send({'id': m['id'], 'result': result})
    if method == 'turn/start':
        send({'id': 100, 'method': 'item/commandExecution/requestApproval',
              'params': {'threadId': params['threadId'], 'command': 'safe-demo'}})

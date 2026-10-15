#!/usr/bin/env python3
"""Inspect the inherited desktop PATH only; never authenticate or start a server."""
import concurrent.futures
import json
import re
import shutil
import subprocess


def backend(name):
    if not shutil.which(name):
        return {'status': 'missing'}
    try:
        result = subprocess.run([name, '--version'], capture_output=True, text=True, timeout=2)
        match = re.search(r'(?<!\d)(\d+)\.(\d+)\.(\d+)', result.stdout or result.stderr)
        if result.returncode or not match:
            return {'status': 'unverified'}
        numbers = tuple(map(int, match.groups()))
        # These are the oldest contracts exercised by this plugin, not a promise
        # of compatibility with every future version.
        minimum = (2, 0, 29) if name == 'opencode' else (0, 162, 1)
        return {'status': 'available' if numbers >= minimum else 'unsupported',
                'version': '.'.join(map(str, numbers))}
    except (OSError, subprocess.SubprocessError):
        return {'status': 'unverified'}


def check():
    names = ('opencode', 'codex')
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        backends = dict(zip(names, executor.map(backend, names)))
    return {'backends': backends, 'tools': {name: bool(shutil.which(name)) for name in
            ('zenity', 'wl-paste', 'hyprctl', 'notify-send', 'xdg-open')}}


if __name__ == '__main__':
    print(json.dumps(check()))

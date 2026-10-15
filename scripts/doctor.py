#!/usr/bin/env python3
"""Read-only dependency checks; never signs in, starts a backend, or sends prompts."""
import argparse
import re
import shutil
import subprocess
import sys


def version(command):
    try:
        result = subprocess.run([command, '--version'], capture_output=True, text=True, timeout=8)
        text = (result.stdout or result.stderr).strip().splitlines()
        return text[0][:160] if text else 'version unavailable'
    except (OSError, subprocess.SubprocessError):
        return 'version unavailable'


def check(backend='auto'):
    errors = []
    if sys.version_info < (3, 11):
        errors.append('Python 3.11 or newer is required')
    print('Python:', sys.version.split()[0])
    if not shutil.which('noctalia'):
        errors.append('Noctalia is missing from PATH')
    else:
        value = version('noctalia')
        print('Noctalia:', value)
        match = re.search(r'(?<!\d)(\d+)\.(\d+)\.(\d+)', value)
        if match and tuple(map(int, match.groups())) < (5, 2, 1):
            errors.append('Use Noctalia 5.2.1 or newer with plugin API 32+')
        elif not match:
            print('NOTE: Could not verify Noctalia version; plugin API 32+ is required.')
    available = {name: bool(shutil.which(name)) for name in ('opencode', 'codex')}
    for name, found in available.items():
        value = version(name) if found else 'not installed'
        print(name + ':', value)
        if name == 'opencode' and found:
            match = re.search(r'(?<!\d)(\d+)\.(\d+)\.(\d+)', value)
            if match and int(match.group(1)) < 2:
                available[name] = False
                print('UNSUPPORTED: OpenCode V1; this plugin requires the v2 service contract.')
    if backend == 'auto' and not any(available.values()):
        errors.append('Install and configure OpenCode v2 or Codex; at least one backend is required')
    elif backend != 'auto' and not available[backend]:
        errors.append('Selected backend is missing: ' + backend)
    for command, feature in [('zenity', 'file attachments and Markdown Save As'),
                             ('wl-paste', 'clipboard images and screenshot attachment'),
                             ('hyprctl', 'automatic Noctalia screenshot attachment (Hyprland only)'),
                             ('notify-send', 'clickable notifications; plain notification fallback remains'),
                             ('xdg-open', 'user-initiated consent links')]:
        print(('OK: ' if shutil.which(command) else 'OPTIONAL MISSING: ') + command + ' — ' + feature)
    print('Configure a terminal in Noctalia for consent/tool workflows that need one.')
    print('Tested backend contracts: OpenCode 2.0.29; Codex CLI 0.162.1. Other versions need verification.')
    print('Backends must also be reachable from Noctalia\'s desktop PATH, not only an interactive shell.')
    for error in errors:
        print('ERROR:', error)
    return not errors


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend', choices=['auto', 'opencode', 'codex'], default='auto')
    args = parser.parse_args()
    raise SystemExit(0 if check(args.backend) else 1)

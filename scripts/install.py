#!/usr/bin/env python3
"""Preview/install/update/remove only the owned Agent Chat plugin payload."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import tomllib

ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ID = 'local/agent-chat'


def manifest():
    return tomllib.loads((ROOT / 'plugin/plugin.toml').read_text())


def owned(destination):
    if destination.is_symlink():
        raise SystemExit('Refusing a symlinked plugin destination')
    if not destination.exists():
        return False
    try:
        marker = json.loads((destination / '.agent-chat-source.json').read_text())
    except (OSError, ValueError):
        raise SystemExit('Refusing a plugin directory without valid Agent Chat ownership metadata')
    # Previous local installers wrote source/version without an id.
    if marker.get('id', PLUGIN_ID) != PLUGIN_ID or not isinstance(marker.get('source'), str):
        raise SystemExit('Refusing foreign plugin ownership metadata')
    return True


def backup_payload(home, destination):
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = home / '.local/state/agent-chat/install-backups' / stamp
    backup.mkdir(parents=True, mode=0o700)
    shutil.copytree(destination, backup / 'plugin', symlinks=True)
    print('Previous payload backup:', backup)
    return backup


def install(home, apply=False, uninstall=False):
    home = Path(home).expanduser().absolute()
    destination = home / '.local/share/noctalia/plugins/agent-chat'
    assistant = home / '.local/share/agent-chat/assistant'
    exists = owned(destination)
    print('Plugin:', destination)
    if uninstall:
        if not apply:
            print('Preview: remove owned plugin payload only. Pass --apply after disabling it in Noctalia.')
        elif exists:
            backup_payload(home, destination)
            shutil.rmtree(destination)
            print('Removed payload. Assistant files, private state, exports and backend history preserved.')
        else:
            print('Plugin is not installed.')
        return
    print('Assistant context:', assistant / 'AGENTS.md', '(preserved)' if (assistant / 'AGENTS.md').exists() else '(new)')
    if not apply:
        print('Preview only; pass --apply to install. No shell settings or shortcuts are changed.')
        return
    if assistant.is_symlink():
        raise SystemExit('Refusing to change a symlinked assistant directory')
    staging = destination.with_name('agent-chat.installing')
    if staging.exists() or staging.is_symlink():
        raise SystemExit('An installation staging path exists; inspect it before retrying')
    previous = destination.with_name('agent-chat.previous')
    if previous.exists() or previous.is_symlink():
        raise SystemExit('A previous installation path exists; inspect it before retrying')
    if exists:
        backup_payload(home, destination)
    staging.parent.mkdir(parents=True, exist_ok=True)
    try:
        staging.mkdir()
        for line in (ROOT / 'PACKAGE-FILES.txt').read_text().splitlines():
            name = line.strip()
            if not name.startswith('plugin/'):
                continue
            relative = Path(name)
            if '..' in relative.parts or (ROOT / relative).is_symlink():
                raise SystemExit('Invalid source payload entry: ' + name)
            target = staging / relative.relative_to('plugin')
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        (staging / '.agent-chat-source.json').write_text(json.dumps({
            'id': PLUGIN_ID, 'source': str(ROOT), 'version': manifest()['version']}))
        assistant.mkdir(parents=True, mode=0o700, exist_ok=True)
        os.chmod(assistant, 0o700)
        context = assistant / 'AGENTS.md'
        if not context.exists() and not context.is_symlink():
            fd = os.open(context, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'w') as out:
                out.write((ROOT / 'docs/assistant-AGENTS.md').read_text())
        if exists:
            destination.rename(previous)
        try:
            staging.rename(destination)
        except BaseException:
            if previous.exists():
                previous.rename(destination)
            raise
        if previous.exists():
            shutil.rmtree(previous)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    print('Installed. Enable with: noctalia msg plugins enable ' + PLUGIN_ID)
    print('Add the bar widget and control-center tile through Noctalia settings; see docs/INSTALL.md.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--uninstall', action='store_true')
    parser.add_argument('--home', type=Path, default=Path.home(), help='alternate home for isolated staging/tests')
    parser.add_argument('--backend', choices=['auto', 'opencode', 'codex'], default='auto')
    parser.add_argument('--skip-checks', action='store_true', help='skip dependency checks for offline staging only')
    args = parser.parse_args()
    if args.apply and not args.uninstall and not args.skip_checks:
        from doctor import check
        if not check(args.backend):
            raise SystemExit('Resolve required dependencies before installation; no payload was changed.')
    install(args.home, args.apply, args.uninstall)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Stage a reviewable community directory; never installs, commits, or publishes."""
import argparse
from pathlib import Path
import re
import shutil
import tomllib

ROOT = Path(__file__).resolve().parents[1]


def stage(output, author='iboldizsar', plugin_api=32):
    if not re.fullmatch(r'[a-z0-9][a-z0-9._-]*', author):
        raise ValueError('Author must be a valid lowercase plugin id segment')
    if plugin_api < 32:
        raise ValueError('This plugin requires API 32 or newer')
    metadata = tomllib.loads((ROOT / 'plugin/plugin.toml').read_text())
    target = Path(output) / 'agent-chat'
    if target.exists() or target.is_symlink():
        raise ValueError('Destination exists; use a new empty output directory')
    entries = []
    for line in (ROOT / 'PACKAGE-FILES.txt').read_text().splitlines():
        name = line.strip()
        if not name.startswith('plugin/'):
            continue
        relative = Path(name)
        if '..' in relative.parts or (ROOT / relative).is_symlink():
            raise ValueError('Invalid payload path')
        entries.append(relative)
    target.mkdir(parents=True)
    for relative in entries:
        destination = target / relative.relative_to('plugin')
        destination.parent.mkdir(parents=True, exist_ok=True)
        if relative.suffix in ('.luau', '.py', '.md', '.toml'):
            text = (ROOT / relative).read_text().replace(metadata['id'], author + '/agent-chat')
            if relative.name == 'plugin.toml':
                text = re.sub(r'(?m)^author = "[^"]+"$', 'author = "' + author + '"', text)
                text = re.sub(r'(?m)^plugin_api = \d+$', 'plugin_api = ' + str(plugin_api), text)
            destination.write_text(text)
        else:
            shutil.copy2(ROOT / relative, destination)
    return target


def blockers(target):
    metadata = tomllib.loads((target / 'plugin.toml').read_text())
    issues = []
    if not (target / 'thumbnail.webp').is_file():
        issues.append('Missing 960x540 thumbnail.webp from a real screenshot')
    if len(metadata['description']) > 120:
        issues.append('Catalog description exceeds 120 characters')
    if len([p for p in target.rglob('*') if p.is_file()]) > 200:
        issues.append('More than 200 files')
    for file in target.rglob('*.luau'):
        if not file.read_text().startswith('--!nonstrict'):
            issues.append('Missing nonstrict directive: ' + file.name)
    return issues


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--author', default='iboldizsar')
    parser.add_argument('--plugin-api', type=int, default=32)
    args = parser.parse_args()
    result = stage(args.output_dir, args.author, args.plugin_api)
    print(result)
    for issue in blockers(result):
        print('SUBMISSION BLOCKER:', issue)

#!/usr/bin/env python3
"""Create the default portable assistant context once; preserve existing files."""
import argparse
import json
import os
from pathlib import Path
import tempfile


def ensure(directory, home=None, template=None):
    home = Path(home) if home is not None else Path.home()
    directory = Path(directory).expanduser().absolute()
    target = directory / 'AGENTS.md'
    if target.is_file():
        return {'ready': True, 'created': False}
    if target.exists() or target.is_symlink():
        return {'error': 'Assistant instructions are not a regular file. Check the configured assistant directory.'}
    default = home / '.local/share/agent-chat/assistant'
    if directory != default or directory.is_symlink():
        return {'error': 'Custom assistant context is missing. Create AGENTS.md there, or select the default assistant directory.'}
    template = Path(template) if template else Path(__file__).resolve().parents[1] / 'assets/assistant-AGENTS.md'
    contents = template.read_bytes()
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=directory, prefix='.agent-chat-context-', delete=False) as output:
            temporary = Path(output.name)
            output.write(contents)
        # Publish a complete file without replacing a concurrent file or symlink.
        try:
            os.link(temporary, target)
        except FileExistsError:
            return {'ready': target.is_file(), 'created': False}
        return {'ready': True, 'created': True}
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(ensure(args.directory)))
    except OSError:
        print(json.dumps({'error': 'Could not create assistant instructions. Check directory access, then reconnect.'}))

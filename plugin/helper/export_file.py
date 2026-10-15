#!/usr/bin/env python3
"""Save an explicitly exported transcript using a native Save As dialog."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def save(source, suggested):
    result = subprocess.run(['zenity', '--file-selection', '--save', '--confirm-overwrite',
                             '--title=Export conversation as Markdown', '--filename=' + suggested,
                             '--file-filter=Markdown files | *.md', '--file-filter=All files | *'],
                            capture_output=True)
    if result.returncode == 1:
        return {'cancelled': True}
    if result.returncode != 0:
        raise ValueError('Could not open the Save As dialog')
    target = Path(os.fsdecode(result.stdout.rstrip(b'\n'))).expanduser()
    if not target.name or not target.parent.is_dir() or target.is_dir():
        raise ValueError('Choose a filename in an existing folder')
    # Atomic replacement avoids following a destination symlink or exposing a partial file.
    temp = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix='.agent-chat-', delete=False) as output:
            temp = Path(output.name)
            output.write(Path(source).read_bytes())
        os.replace(temp, target)
    finally:
        if temp is not None:
            temp.unlink(missing_ok=True)
    return {'path': str(target)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True)
    parser.add_argument('--suggested', required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(save(args.source, args.suggested)))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(json.dumps({'error': str(error)[:300]}))


if __name__ == '__main__':
    main()

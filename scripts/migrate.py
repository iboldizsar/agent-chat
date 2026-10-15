#!/usr/bin/env python3
"""Preview/copy private state to the public namespace; never enables plugins."""
import argparse
import os
from pathlib import Path
import shutil
import stat

OLD = 'local/agent-chat'
NEW = 'iboldizsar/agent-chat'


def paths(home):
    base = Path(home).expanduser().absolute() / '.local/state/noctalia/plugins/data'
    return base / OLD, base / NEW


def snapshot(folder):
    rows = {}
    for path in [folder, *folder.rglob('*')]:
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode) or not (stat.S_ISREG(info.st_mode) or stat.S_ISDIR(info.st_mode)):
            raise ValueError('Migration refuses symlinks and special files in private state')
        rows[str(path.relative_to(folder))] = (info.st_ino, info.st_size, info.st_mtime_ns, stat.S_ISDIR(info.st_mode))
    return rows


def migrate(home, apply=False):
    source, target = paths(home)
    # Do not follow a redirected state namespace or overwrite a newer install.
    for path in (source, target):
        for parent in [path, *path.parents]:
            if parent.is_symlink():
                raise ValueError('Migration refuses a symlinked state path')
    if not source.is_dir():
        raise ValueError('Old plugin state was not found; fresh public installs do not need migration')
    if target.exists():
        raise ValueError('Public plugin state already exists; it will not be overwritten')
    staging = target.with_name('agent-chat.migrating')
    if staging.exists() or staging.is_symlink():
        raise ValueError('An unfinished migration exists; inspect it before retrying')
    if (source / 'preferences.json.writing').exists():
        raise ValueError('Resolve the old pending preference write before migration')
    before = snapshot(source)
    report = {'source': str(source), 'destination': str(target), 'files': sum(not row[3] for row in before.values()), 'applied': False}
    if not apply:
        return report
    # Stop/disable both namespaces before applying. Detect normal concurrent
    # writes as an additional guard, not as a substitute for that precondition.
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        shutil.copytree(source, staging)
        for path in staging.rglob('*'):
            os.chmod(path, 0o700 if path.is_dir() else 0o600)
        os.chmod(staging, 0o700)
        if snapshot(source) != before:
            raise ValueError('Old state changed while copying. Disable both plugins, then retry')
        # mkdir provides an exclusive destination reservation. Do not use rename
        # over an existing directory: another install may have just created it.
        target.mkdir(mode=0o700)
        try:
            for child in staging.iterdir():
                child.rename(target / child.name)
        except BaseException:
            # Keep a partial destination for inspection; never replace it on retry.
            raise
        staging.rmdir()
        report['applied'] = True
        return report
    finally:
        if staging.exists():
            shutil.rmtree(staging)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, default=Path.home())
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    try:
        result = migrate(args.home, args.apply)
        print('Source:', result['source'])
        print('Destination:', result['destination'])
        print('Private files:', result['files'])
        print('Copied.' if result['applied'] else 'Preview only. Disable both plugin IDs before applying.')
        print('Original state and attachment paths are preserved. Settings, placements and shortcuts are not changed.')
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))

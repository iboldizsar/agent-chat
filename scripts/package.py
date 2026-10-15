#!/usr/bin/env python3
"""Build an allowlisted reproducible private release archive and SHA-256 checksum."""
import argparse
import gzip
import hashlib
import io
from pathlib import Path, PurePosixPath
import tarfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]


def build(output, root=ROOT):
    root, output = Path(root), Path(output)
    version = tomllib.loads((root / 'plugin/plugin.toml').read_text())['version']
    prefix = 'agent-chat-' + version
    entries = []
    for line in (root / 'PACKAGE-FILES.txt').read_text().splitlines():
        name = line.strip()
        if not name or name.startswith('#'):
            continue
        relative = PurePosixPath(name)
        if relative.is_absolute() or '..' in relative.parts or name in entries:
            raise ValueError('Invalid or duplicate package entry: ' + name)
        path = root / name
        if path.is_symlink() or any((root / Path(*relative.parts[:n])).is_symlink() for n in range(1, len(relative.parts))):
            raise ValueError('Symlinks are not allowed in release payloads: ' + name)
        if not path.is_file():
            raise ValueError('Missing release file: ' + name)
        entries.append(name)
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode='w', format=tarfile.PAX_FORMAT) as archive:
        for name in sorted(entries):
            data = (root / name).read_bytes()
            info = tarfile.TarInfo(prefix + '/' + name)
            info.size = len(data)
            info.mode = 0o755 if name.startswith('scripts/') and name.endswith('.py') else 0o644
            info.uid = info.gid = info.mtime = 0
            info.uname = info.gname = ''
            archive.addfile(info, io.BytesIO(data))
    output.mkdir(parents=True, exist_ok=True)
    target = output / (prefix + '.tar.gz')
    with target.open('wb') as file:
        with gzip.GzipFile(filename='', fileobj=file, mode='wb', mtime=0) as compressed:
            compressed.write(buffer.getvalue())
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    checksum = target.with_suffix(target.suffix + '.sha256')
    checksum.write_text(digest + '  ' + target.name + '\n')
    print(target)
    print(checksum)
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'dist')
    args = parser.parse_args()
    build(args.output_dir)

#!/usr/bin/env python3
"""Capture explicit file/image selections into a private, durable attachment cache."""
import argparse
import json
import mimetypes
import os
from pathlib import Path
import subprocess
import uuid
import time
import shutil
import struct

LIMIT = 8 * 1024 * 1024


def check_image(data, mime):
    if not mime.startswith('image/'):
        return False
    # Reject obvious invalid or mislabeled image inputs without adding a decoder
    # dependency. Native controls own decoding; these are signature checks only.
    known = ((mime == 'image/png' and data.startswith(b'\x89PNG\r\n\x1a\n') and len(data) >= 33)
             or (mime == 'image/jpeg' and data.startswith(b'\xff\xd8\xff') and data.endswith(b'\xff\xd9'))
             or (mime == 'image/webp' and data[:4] == b'RIFF' and data[8:12] == b'WEBP' and len(data) >= 30)
             or (mime == 'image/gif' and data[:6] in (b'GIF87a', b'GIF89a') and len(data) >= 14))
    if mime not in ('image/png', 'image/jpeg', 'image/webp', 'image/gif'):
        return False  # Other formats stay explicit local file references.
    if not known:
        raise ValueError('Image data is invalid or does not match its file type. Choose another file.')
    if mime == 'image/png':
        width, height = struct.unpack('>II', data[16:24])
        if not width or not height or width * height > 32000000:
            raise ValueError('Image dimensions are too large or invalid for preview. Use a smaller image.')
    return True


def clipboard_png():
    r = subprocess.run(['wl-paste', '--no-newline', '--type', 'image/png'], capture_output=True, timeout=5)
    return r.stdout if r.returncode == 0 else b''


def capture_overlay_active(value):
    if isinstance(value, dict):
        if value.get('namespace') in ('noctalia-screenshot-region', 'noctalia-annotate'):
            return True
        return any(capture_overlay_active(v) for v in value.values())
    if isinstance(value, list):
        return any(capture_overlay_active(v) for v in value)
    return False


def screenshot_png():
    # Observe Noctalia's existing capture/annotation surfaces, including cancellation.
    # Never attach the previous clipboard image after a cancelled capture.
    if not shutil.which("wl-paste"):
        raise ValueError("Screenshot attachment requires wl-clipboard. Install it, then try again.")
    if not shutil.which("hyprctl"):
        raise ValueError("Automatic screenshot attachment currently requires Hyprland. Capture a screenshot with your desktop tools, then use Paste image.")
    before = clipboard_png()
    r = subprocess.run(['noctalia', 'msg', 'screenshot-region'], capture_output=True, timeout=5)
    if r.returncode != 0:
        raise ValueError('Could not start Noctalia screenshot capture')
    started, gone_at = False, None
    deadline = time.monotonic() + 10
    while True:
        layers = json.loads(subprocess.check_output(['hyprctl', '-j', 'layers'], timeout=5))
        active = capture_overlay_active(layers)
        now = time.monotonic()
        if active:
            started, gone_at = True, None
        elif started:
            if gone_at is None:
                gone_at = now
            if now - gone_at >= 1:
                after = clipboard_png()
                if not after or after == before:
                    return None
                return after
        elif now >= deadline:
            raise ValueError('Noctalia screenshot overlay did not open')
        time.sleep(0.2)


def capture(mode, directory):
    directory = Path(directory).expanduser()
    directory.mkdir(parents=True, mode=0o700, exist_ok=True)
    os.chmod(directory, 0o700)
    if mode == 'screenshot':
        data = screenshot_png()
        if data is None:
            return {'cancelled': True, 'reason': 'no-new-image'}
        name, mime = 'Screenshot.png', 'image/png'
    elif mode == 'paste':
        offered = subprocess.check_output(['wl-paste', '--list-types'], timeout=5).decode().splitlines()
        mime = next((x for x in ['image/png', 'image/jpeg', 'image/webp'] if x in offered), None)
        if not mime:
            raise ValueError('Clipboard does not contain a supported image')
        data = subprocess.check_output(['wl-paste', '--no-newline', '--type', mime], timeout=5)
        name = 'Pasted image' + mimetypes.guess_extension(mime)
    else:
        r = subprocess.run(['zenity', '--file-selection', '--title=Attach a file (up to 8 MiB)'], capture_output=True)
        if r.returncode == 1:
            return {'cancelled': True}
        if r.returncode != 0:
            raise ValueError("File picker could not open. Check the desktop session and Zenity installation.")
        source = Path(os.fsdecode(r.stdout.rstrip(b'\n')))
        if not source.is_file() or source.stat().st_size > LIMIT:
            raise ValueError('Choose a regular file smaller than 8 MiB')
        with source.open("rb") as selected:
            data = selected.read(LIMIT + 1)
        name = source.name
        mime = mimetypes.guess_type(name)[0] or 'application/octet-stream'
    if len(data) > LIMIT:
        raise ValueError('Attachment exceeds 8 MiB')
    image = check_image(data, mime)
    path = directory / (uuid.uuid4().hex + Path(name).suffix)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as out:
        out.write(data)
    return {'path': str(path), 'uri': path.as_uri(), 'name': name,
            'mime': mime, 'image': image, 'size': len(data)}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('mode', choices=['pick', 'paste', 'screenshot'])
    p.add_argument('--directory', required=True)
    args = p.parse_args()
    try:
        print(json.dumps(capture(args.mode, args.directory)))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(json.dumps({'error': str(error)[:300]}))


if __name__ == '__main__':
    main()

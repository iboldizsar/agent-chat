#!/usr/bin/env python3
"""Supervise one interactive helper and always produce a single JSON result."""
import argparse
import json
import os
import signal
import subprocess
import sys


def run(command):
    if not command:
        return {"error": "Desktop helper command is missing."}
    child = None
    previous = {}

    def terminate(_signum, _frame):
        if child is not None and child.poll() is None:
            os.killpg(child.pid, signal.SIGTERM)
        raise InterruptedError('Interactive operation was interrupted')

    try:
        for number in (signal.SIGTERM, signal.SIGINT):
            previous[number] = signal.signal(number, terminate)
        child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
        while True:
            try:
                stdout, _ = child.communicate(timeout=2)
                break
            except subprocess.TimeoutExpired:
                # Liveness is separate from the time a user spends in a dialog.
                print("@agent-chat:alive", flush=True)
        if child.returncode != 0:
            return {'error': 'Desktop helper exited unexpectedly (code ' + str(child.returncode) + ').'}
        if len(stdout) > 65536:
            return {'error': 'Desktop helper returned an oversized result.'}
        lines = stdout.decode().splitlines()
        if len(lines) != 1:
            return {'error': 'Desktop helper exited without a valid result.'}
        value = json.loads(lines[0])
        if not isinstance(value, dict):
            return {'error': 'Desktop helper returned an invalid result.'}
        return value
    except (OSError, ValueError, UnicodeError, InterruptedError):
        return {'error': 'Desktop helper could not complete the operation.'}
    finally:
        # Native stream teardown must not strand an external picker.
        if child is not None:
            for number in (signal.SIGTERM, signal.SIGKILL):
                try:
                    os.killpg(child.pid, number)
                    child.wait(timeout=2)
                    break
                except ProcessLookupError:
                    break
                except subprocess.TimeoutExpired:
                    continue
        for number, handler in previous.items():
            signal.signal(number, handler)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    print(json.dumps(run(args.command)), flush=True)


if __name__ == '__main__':
    main()

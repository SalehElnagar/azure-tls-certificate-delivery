#!/usr/bin/env python3
"""Check a downloaded issuer ZIP against the reviewed release lock."""
import argparse
import hashlib
import json
from pathlib import Path
import sys


def verify(path, lock):
    hasher = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    if digest != lock['sha256']:
        raise ValueError('issuer package digest mismatch')
    return {'status': 'verified', 'version': lock['version'], 'sha256': digest}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package', type=Path)
    args = parser.parse_args()
    try:
        lock = json.loads((Path(__file__).resolve().parents[1] / 'upstream.lock.json').read_text())
        print(json.dumps(verify(args.package, lock), sort_keys=True))
    except (OSError, ValueError) as error:
        print(json.dumps({'status': 'failed', 'reason': type(error).__name__}), file=sys.stderr)
        raise SystemExit(1)

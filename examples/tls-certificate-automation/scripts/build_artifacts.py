#!/usr/bin/env python3
"""Prepare deterministic demo ZIP or an exact public-certificate Run Command script."""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def demo_zip(output):
    info = zipfile.ZipInfo('app.py', date_time=(1980, 1, 1, 0, 0, 0))
    info.external_attr = 0o100644 << 16
    with zipfile.ZipFile(output, mode='x', compression=zipfile.ZIP_STORED) as archive:
        archive.writestr(info, (ROOT/'demo/app.py').read_bytes())


def verifier_script(output, vault_url, certificate, client_id):
    source = (ROOT/'scripts/public_certificate.py').read_text()
    marker = 'TLS_PUBLIC_' + hashlib.sha256(source.encode()).hexdigest()
    command = shlex.join(['python3', '-', '--vault-url', vault_url, '--certificate', certificate, '--client-id', client_id])
    body = '#!/bin/sh\nset -eu\n' + command + " <<'" + marker + "'\n" + source + '\n' + marker + '\n'
    with output.open('x') as stream: stream.write(body)
    output.chmod(0o600)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='kind', required=True)
    demo = commands.add_parser('demo')
    demo.add_argument('--output', type=Path, required=True)
    verifier = commands.add_parser('verifier')
    verifier.add_argument('--output', type=Path, required=True)
    verifier.add_argument('--vault-url', required=True)
    verifier.add_argument('--certificate', required=True)
    verifier.add_argument('--client-id', required=True)
    args = parser.parse_args()
    if args.kind == 'demo': demo_zip(args.output)
    else: verifier_script(args.output, args.vault_url, args.certificate, args.client_id)
    print(json.dumps({'artifact_sha256': hashlib.sha256(args.output.read_bytes()).hexdigest()}))

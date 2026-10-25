#!/usr/bin/env python3
"""Verify the certificate delivered to a TLS client, without fetching private keys."""
import argparse
from datetime import datetime, timezone
import hashlib
import hmac
import json
import math
import re
import socket
import ssl
import sys
import time


class ProbeError(ValueError):
    pass


def context_for(cafile):
    context = ssl.create_default_context(cafile=cafile)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    return context


def observe(hostname, expected_sha256, min_days=7, *, port=443, connect_to=None, cafile=None, now=None):
    if not re.fullmatch(r'[a-zA-Z0-9](?:[a-zA-Z0-9.-]{0,251}[a-zA-Z0-9])?', hostname) or '..' in hostname:
        raise ProbeError('invalid hostname')
    if not re.fullmatch(r'[0-9a-fA-F]{64}', expected_sha256):
        raise ProbeError('expected fingerprint must be a SHA-256 hex digest')
    if not math.isfinite(min_days) or min_days < 0 or not 1 <= port <= 65535:
        raise ProbeError('invalid validity threshold or port')
    context = context_for(cafile)
    with socket.create_connection((connect_to or hostname, port), timeout=10) as connection:
        with context.wrap_socket(connection, server_hostname=hostname) as tls:
            der = tls.getpeercert(binary_form=True)
            expires = ssl.cert_time_to_seconds(tls.getpeercert()['notAfter'])
    observed = time.time() if now is None else now
    fingerprint = hashlib.sha256(der).hexdigest()
    if not hmac.compare_digest(fingerprint, expected_sha256.lower()):
        raise ProbeError('served certificate fingerprint differs from expected version')
    remaining = (expires - observed) / 86400
    if expires <= observed or remaining < min_days:
        raise ProbeError('served certificate has insufficient remaining validity')
    return {
        'schema_version': 1,
        'status': 'verified',
        'observed_at': datetime.fromtimestamp(observed, timezone.utc).isoformat(),
        'hostname': hostname,
        'sha256': fingerprint,
        'not_after': datetime.fromtimestamp(expires, timezone.utc).isoformat(),
        'remaining_days': round(remaining, 4),
        'trust_store': 'explicit-ca-file' if cafile else 'system',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--hostname', required=True)
    parser.add_argument('--expected-sha256', required=True)
    parser.add_argument('--min-days', type=float, default=7)
    parser.add_argument('--port', type=int, default=443)
    parser.add_argument('--connect-to', help='Optional address override; SNI and hostname verification still use --hostname')
    parser.add_argument('--ca-file', help='Explicit test/staging CA file; never disables chain verification')
    args = parser.parse_args()
    try:
        result = observe(args.hostname, args.expected_sha256, args.min_days, port=args.port, connect_to=args.connect_to, cafile=args.ca_file)
    except (ProbeError, OSError, ssl.SSLError, KeyError, OverflowError) as error:
        # Network/OpenSSL errors can contain operational details; expose only a class.
        reason = str(error) if isinstance(error, ProbeError) else type(error).__name__
        print(json.dumps({'status': 'failed', 'reason': reason}), file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

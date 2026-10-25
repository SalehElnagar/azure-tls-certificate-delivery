#!/usr/bin/env python3
"""Explicit live issuance/renewal client; never run from credential-free source CI."""
import argparse
from contextlib import nullcontext
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


class ClientError(ValueError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None  # Never forward a bearer token through an HTTP redirect.


def operation_url(request_url, location):
    if not location:
        raise ClientError('issuer did not return an operation location')
    target = urllib.parse.urljoin(request_url, location)
    before, after = urllib.parse.urlsplit(request_url), urllib.parse.urlsplit(target)
    if (after.scheme, after.netloc) != (before.scheme, before.netloc) or after.fragment or after.query or not re.fullmatch(r'/api/operations/[A-Za-z0-9_-]+', after.path):
        raise ClientError('issuer returned an unapproved operation location')
    return target


def send(opener, url, token, *, data=None, method='GET'):
    request = urllib.request.Request(url, data=data, method=method, headers={
        'Authorization': 'Bearer ' + token, 'Accept': 'application/json', 'Content-Type': 'application/json'})
    try:
        with opener.open(request, timeout=10) as response:
            return response.status, response.headers.get('Location')
    except urllib.error.HTTPError as error:
        raise ClientError('issuer returned HTTP ' + str(error.code)) from None
    except (OSError, urllib.error.URLError):
        raise ClientError('network outcome uncertain; inspect existing operation/certificates before any new request') from None


def private_receipt(path):
    if path is None:
        return nullcontext()
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    return os.fdopen(descriptor, 'w')


def record_operation(journal, status, request_url, operation=None):
    if journal is None:
        return
    observation = {'status': status, 'request_url': request_url,
                   'observed_at': datetime.now(timezone.utc).isoformat()}
    if operation is not None:
        observation['operation_url'] = operation
    journal.seek(0)
    json.dump(observation, journal)
    journal.truncate()
    journal.flush()
    os.fsync(journal.fileno())


def wait_for_completion(opener, target, token, deadline):
    while time.monotonic() < deadline:
        status, _ = send(opener, target, token)
        if status == 200:
            return
        if status != 202:
            raise ClientError('unexpected operation status')
        time.sleep(min(5, max(0, deadline - time.monotonic())))
    raise ClientError('operation observation timed out; reconcile before any new request')


def start_and_wait(url, body, token, timeout=600, *, receipt=None):
    # The keyword receipt preserves existing callers while adding recovery evidence.
    with private_receipt(receipt) as journal:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        deadline = time.monotonic() + timeout
        record_operation(journal, 'post-attempted', url)
        status, location = send(opener, url, token, data=body, method='POST')
        if status != 202:
            raise ClientError('issuer did not return asynchronous acceptance')
        target = operation_url(url, location)
        record_operation(journal, 'accepted', url, target)
        wait_for_completion(opener, target, token, deadline)
        record_operation(journal, 'completed', url, target)


def cli_token(subscription, scope):
    if not re.fullmatch(r'api://[a-fA-F0-9-]{36}/user_impersonation', scope):
        raise ClientError('use the reviewed issuer API user_impersonation scope')
    result = subprocess.run(['az', 'account', 'get-access-token', '--subscription', subscription,
        '--scope', scope, '--only-show-errors', '--output', 'json'], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise ClientError('Azure CLI token acquisition failed; no automatic login or credential fallback')
    try:
        token = json.loads(result.stdout)['accessToken']
        if not isinstance(token, str) or not token or any(c in token for c in '\r\n'):
            raise ClientError('token response was invalid')
        return token
    except (ValueError, KeyError):
        raise ClientError('token response was invalid') from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--endpoint', required=True)
    parser.add_argument('--subscription', required=True)
    parser.add_argument('--scope', required=True)
    parser.add_argument('--receipt', type=Path, help='New private operation receipt; an existing path prevents another POST')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--issue-request', type=Path)
    group.add_argument('--renew')
    args = parser.parse_args()
    if not re.fullmatch(r'https://[a-z0-9-]+\.azurewebsites\.net', args.endpoint):
        raise ClientError('use the exact reviewed issuer HTTPS origin without a trailing slash')
    if args.issue_request:
        body = json.dumps(json.loads(args.issue_request.read_text())).encode()
        path = '/api/certificates'
    else:
        if not re.fullmatch(r'[a-zA-Z0-9-]{1,127}', args.renew):
            raise ClientError('invalid certificate name')
        body, path = b'', '/api/certificates/' + args.renew + '/renew'
    token = cli_token(args.subscription, args.scope)
    start_and_wait(args.endpoint + path, body, token, receipt=args.receipt)
    print(json.dumps({'status': 'api-completed', 'certificate_readback_required': True}))


if __name__ == '__main__':
    try:
        main()
    except (ClientError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        reason = str(error) if isinstance(error, ClientError) else type(error).__name__
        print(json.dumps({'status': 'failed', 'reason': reason}), file=sys.stderr)
        raise SystemExit(1)

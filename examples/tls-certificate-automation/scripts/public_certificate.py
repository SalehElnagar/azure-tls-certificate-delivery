#!/usr/bin/env python3
"""Run on the private verifier VM: read ONLY a Key Vault public certificate."""
import argparse
import base64
import hashlib
import json
import re
import urllib.parse
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None


def public_identity(vault_url, name, client_id):
    if not re.fullmatch(r'https://[a-z0-9-]+\.vault\.azure\.net/', vault_url):
        raise ValueError('invalid vault URI')
    if not re.fullmatch(r'[a-zA-Z0-9-]{1,127}', name):
        raise ValueError('invalid certificate name')
    # Never use /secrets/: /certificates/ returns public X.509 bytes and metadata.
    query = urllib.parse.urlencode({'api-version': '2018-02-01', 'resource': 'https://vault.azure.net', 'client_id': client_id})
    imds = 'http://169.254.169.254/metadata/identity/oauth2/token?' + query
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    with opener.open(urllib.request.Request(imds, headers={'Metadata': 'true'}), timeout=10) as response:
        token = json.load(response)['access_token']
    uri = vault_url + 'certificates/' + name + '?api-version=7.4'
    request = urllib.request.Request(uri, headers={'Authorization': 'Bearer ' + token})
    with opener.open(request, timeout=10) as response:
        certificate = json.load(response)
    if not certificate['attributes'].get('enabled', False):
        raise ValueError('certificate is disabled')
    der = base64.b64decode(certificate['cer'], validate=True)
    return {'certificate_name': name, 'sha256': hashlib.sha256(der).hexdigest(), 'expires_epoch': certificate['attributes']['exp']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vault-url', required=True)
    parser.add_argument('--certificate', required=True)
    parser.add_argument('--client-id', required=True)
    args = parser.parse_args()
    print(json.dumps(public_identity(args.vault_url, args.certificate, args.client_id), sort_keys=True))

"""Test package integrity and the public-only Key Vault data boundary."""
import base64
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import urllib.request
import urllib.error
from email.message import Message
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

package, public = load('verify_package'), load('public_certificate')

class CustodyTests(unittest.TestCase):
    def test_public_certificate_transport_refuses_bearer_redirect(self):
        visited = []
        class Transport(urllib.request.BaseHandler):
            handler_order = 100
            def http_open(self, request):
                visited.append(request.full_url)
                headers = Message()
                if request.full_url.startswith('http://169.254.169.254/'):
                    body, status = json.dumps({'access_token': 'synthetic-token'}).encode(), 200
                elif request.full_url.startswith('https://kv-example.vault.azure.net/'):
                    body, status = b'', 302
                    headers['Location'] = 'https://other.example/capture'
                else:
                    raise AssertionError('bearer request escaped the approved vault')
                response = urllib.request.addinfourl(io.BytesIO(body), headers, request.full_url, status)
                response.msg = 'synthetic response'
                return response
            https_open = http_open
        real_opener = urllib.request.build_opener
        with patch.object(public.urllib.request, 'build_opener', side_effect=lambda *handlers: real_opener(*handlers, Transport())):
            with self.assertRaises(urllib.error.HTTPError) as denied:
                public.public_identity('https://kv-example.vault.azure.net/', 'app-one', 'synthetic-client')
        self.assertEqual(denied.exception.code, 302)
        self.assertEqual(len(visited), 2)

    def test_modified_package_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'issuer.zip'
            path.write_bytes(b'reviewed fixture')
            lock = {'version': 'fixture', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            self.assertEqual(package.verify(path, lock)['status'], 'verified')
            path.write_bytes(b'replaced package')
            with self.assertRaisesRegex(ValueError, 'digest mismatch'):
                package.verify(path, lock)

    def test_expected_hash_comes_from_public_certificate_not_a_secret(self):
        class Endpoint:
            def __init__(self): self.paths = []
            def open(self, request, timeout):
                self.paths.append(request.full_url)
                body = {'access_token': 'synthetic-token'} if len(self.paths) == 1 else {
                    'cer': base64.b64encode(b'public-certificate-fixture').decode(),
                    'attributes': {'enabled': True, 'exp': 1900000000}}
                return io.BytesIO(json.dumps(body).encode())
        endpoint = Endpoint()
        with patch.object(public.urllib.request, 'build_opener', return_value=endpoint):
            result = public.public_identity('https://kv-example.vault.azure.net/', 'app-one', 'synthetic-client')
        self.assertEqual(result['sha256'], hashlib.sha256(b'public-certificate-fixture').hexdigest())
        self.assertIn('/certificates/app-one?', endpoint.paths[-1])
        self.assertNotIn('/secrets/', endpoint.paths[-1])
        self.assertNotIn('synthetic-token', json.dumps(result))

if __name__ == '__main__': unittest.main()

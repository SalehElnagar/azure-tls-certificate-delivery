"""Deny token forwarding and ambiguous automatic retries at real I/O boundaries."""
import importlib.util
import io
import json
from types import SimpleNamespace
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch

path = Path(__file__).resolve().parents[1]/'scripts/issuer_request.py'
spec = importlib.util.spec_from_file_location('issuer', path)
issuer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(issuer)

class Response(io.BytesIO):
    def __init__(self, status, location=None):
        super().__init__(b'')
        self.status = status
        self.headers = {'Location': location} if location else {}

class IssuerClientTests(unittest.TestCase):
    def test_cross_origin_operation_location_is_rejected_before_token_forwarding(self):
        with self.assertRaises(issuer.ClientError):
            issuer.operation_url('https://func-example.azurewebsites.net/api/certificates', 'https://other.example/api/operations/1')

    def test_relative_operation_location_uses_the_request_origin(self):
        self.assertEqual(issuer.operation_url('https://func-example.azurewebsites.net/api/certificates', '/api/operations/1'), 'https://func-example.azurewebsites.net/api/operations/1')

    def test_accepted_is_polled_until_completed_without_repeating_issuance(self):
        responses = [Response(202, '/api/operations/1'), Response(202), Response(200)]
        class Endpoint:
            def __init__(self): self.methods=[]
            def open(self, request, timeout):
                self.methods.append(request.method)
                return responses.pop(0)
        endpoint=Endpoint()
        with patch.object(issuer.urllib.request,'build_opener',return_value=endpoint), patch.object(issuer.time,'sleep'):
            issuer.start_and_wait('https://func-example.azurewebsites.net/api/certificates', b'{}', 'synthetic-token')
        self.assertEqual(endpoint.methods,['POST','GET','GET'])

    def test_unknown_post_outcome_is_not_retried(self):
        class Endpoint:
            def __init__(self): self.calls=0
            def open(self, request, timeout):
                self.calls+=1
                raise TimeoutError('synthetic timeout')
        endpoint=Endpoint()
        with patch.object(issuer.urllib.request,'build_opener',return_value=endpoint), self.assertRaises(issuer.ClientError):
            issuer.start_and_wait('https://func-example.azurewebsites.net/api/certificates', b'{}', 'synthetic-token')
        self.assertEqual(endpoint.calls,1)

    def test_accepted_operation_receipt_survives_status_failure(self):
        class Endpoint:
            def __init__(self): self.calls = 0
            def open(self, request, timeout):
                self.calls += 1
                if self.calls == 1: return Response(202, '/api/operations/1')
                raise TimeoutError('synthetic polling timeout')
        endpoint = Endpoint()
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / 'operation.json'
            with patch.object(issuer.urllib.request, 'build_opener', return_value=endpoint), self.assertRaises(issuer.ClientError):
                issuer.start_and_wait('https://func-example.azurewebsites.net/api/certificates', b'{}', 'synthetic-token', receipt=receipt)
            saved = json.loads(receipt.read_text())
            self.assertEqual(saved['status'], 'accepted')
            self.assertEqual(saved['operation_url'], 'https://func-example.azurewebsites.net/api/operations/1')
            self.assertNotIn('synthetic-token', receipt.read_text())
            self.assertEqual(receipt.stat().st_mode & 0o777, 0o600)
            self.assertEqual(endpoint.calls, 2)

    def test_completed_receipt_retains_the_reconciliation_url(self):
        class Endpoint:
            def open(self, request, timeout):
                return Response(202, '/api/operations/1') if request.method == 'POST' else Response(200)
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / 'operation.json'
            with patch.object(issuer.urllib.request, 'build_opener', return_value=Endpoint()):
                issuer.start_and_wait('https://func-example.azurewebsites.net/api/certificates', b'{}', 'synthetic-token', receipt=receipt)
            saved = json.loads(receipt.read_text())
            self.assertEqual(saved['status'], 'completed')
            self.assertEqual(saved['operation_url'], 'https://func-example.azurewebsites.net/api/operations/1')

    def test_existing_receipt_prevents_another_post(self):
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / 'operation.json'
            receipt.write_text('prior operation')
            with patch.object(issuer.urllib.request, 'build_opener') as opener, self.assertRaises(FileExistsError):
                issuer.start_and_wait('https://func-example.azurewebsites.net/api/certificates', b'{}', 'synthetic-token', receipt=receipt)
            opener.return_value.open.assert_not_called()
            self.assertEqual(receipt.read_text(), 'prior operation')

    def test_token_acquisition_errors_do_not_expose_credential_output(self):
        for result in [SimpleNamespace(returncode=1, stdout='synthetic-credential'), SimpleNamespace(returncode=0, stdout=json.dumps({'accessToken': None}))]:
            with self.subTest(code=result.returncode), patch.object(issuer.subprocess, 'run', return_value=result):
                with self.assertRaises(issuer.ClientError) as raised:
                    issuer.cli_token('synthetic-subscription', 'api://00000000-0000-0000-0000-000000000000/user_impersonation')
                self.assertNotIn('synthetic-credential', str(raised.exception))

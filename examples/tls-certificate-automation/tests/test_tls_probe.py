"""Behavioral tests at the TLS network boundary; no Azure access."""
import hashlib
import importlib.util
from pathlib import Path
import ssl
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'tls_probe.py'
spec = importlib.util.spec_from_file_location('tls_probe', SCRIPT)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class Peer:
    def __init__(self, der, expires):
        self.der, self.expires = der, expires
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def getpeercert(self, binary_form=False):
        return self.der if binary_form else {'notAfter': self.expires}


class ProbeTests(unittest.TestCase):
    def invoke(self, fingerprint=None, expires='Jan  1 00:00:00 2030 GMT', error=None, days=7):
        peer = Peer(b'synthetic-certificate', expires)
        # SSLContext.wrap_socket is the trust/hostname-verification boundary.
        # Returning a peer models successful TLS verification; verification errors
        # model wrong hostname or untrusted CA. Real network proof is separate.
        with patch.object(ssl.SSLContext, 'wrap_socket', side_effect=error, return_value=peer):
            with patch.object(probe.socket, 'create_connection'):
                result = probe.observe('app.example.com', fingerprint or hashlib.sha256(peer.der).hexdigest(), days, now=1704067200)
        return result

    def test_expected_certificate_is_reported_without_raw_material(self):
        result = self.invoke()
        self.assertEqual(result['status'], 'verified')
        self.assertEqual(result['hostname'], 'app.example.com')
        self.assertNotIn('certificate', result)
        self.assertNotIn('private_key', result)

    def test_old_certificate_and_low_validity_are_rejected(self):
        for kwargs, message in [({'fingerprint': '0' * 64}, 'fingerprint'), ({'expires': 'Jan  2 00:00:00 2024 GMT'}, 'validity')]:
            with self.subTest(kwargs=kwargs), self.assertRaisesRegex(probe.ProbeError, message):
                self.invoke(**kwargs)

    def test_failed_tls_verification_is_never_reported_as_rotation_success(self):
        for text in ['hostname mismatch', 'self-signed certificate']:
            with self.subTest(text=text), self.assertRaises(ssl.SSLCertVerificationError):
                self.invoke(error=ssl.SSLCertVerificationError(text))

    def test_inputs_cannot_disable_verification_or_supply_invalid_thresholds(self):
        for fingerprint, days in [('not-a-hash', 7), ('a' * 64, -1), ('a' * 64, float('nan'))]:
            with self.subTest(fingerprint=fingerprint, days=days), self.assertRaises(probe.ProbeError):
                probe.observe('app.example.com', fingerprint, days)

    def test_production_context_requires_certificate_and_hostname_validation(self):
        context = probe.context_for(None)
        self.assertTrue(context.check_hostname)
        self.assertEqual(context.verify_mode, ssl.CERT_REQUIRED)
        self.assertGreaterEqual(context.minimum_version, ssl.TLSVersion.TLSv1_2)


if __name__ == '__main__': unittest.main()

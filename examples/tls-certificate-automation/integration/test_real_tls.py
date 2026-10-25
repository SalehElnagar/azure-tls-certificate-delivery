"""Real loopback TLS using ephemeral keys, never retained in the source tree."""
import contextlib
import hashlib
import importlib.util
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('probe', ROOT / 'scripts/tls_probe.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def openssl(*args):
    subprocess.run(['openssl', *map(str, args)], check=True, capture_output=True, timeout=20)


@contextlib.contextmanager
def server(cert, key):
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key)
    listener = socket.socket()
    listener.bind(('127.0.0.1', 0))
    listener.listen()
    listener.settimeout(0.2)
    stopped = threading.Event()
    def serve():
        while not stopped.is_set():
            try: connection, _ = listener.accept()
            except socket.timeout: continue
            except OSError: break
            with connection:
                connection.settimeout(3)
                try:
                    with context.wrap_socket(connection, server_side=True): pass
                except ssl.SSLError: pass  # Expected when negative clients reject trust/hostname.
    worker = threading.Thread(target=serve, daemon=True)
    worker.start()
    try: yield listener.getsockname()[1]
    finally:
        stopped.set()
        worker.join(timeout=4)
        listener.close()
        if worker.is_alive(): raise RuntimeError('TLS fixture did not stop')


class RealTLS(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.root = Path(cls.temporary.name)
        cls.ca, cls.ca_key = cls.root/'ca.pem', cls.root/'ca.key'
        openssl('req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2', '-subj', '/CN=Ephemeral TLS Test CA', '-addext', 'basicConstraints=critical,CA:TRUE', '-addext', 'keyUsage=critical,keyCertSign,cRLSign', '-keyout', cls.ca_key, '-out', cls.ca)
        extensions = cls.root/'extensions.cnf'
        extensions.write_text('basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:one.example.test\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\n')
        cls.certificates = {}
        for version in ['1', '2']:
            key, csr, cert = [cls.root/(version+suffix) for suffix in ['.key', '.csr', '.pem']]
            openssl('req', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=one.example.test', '-keyout', key, '-out', csr)
            openssl('x509', '-req', '-in', csr, '-CA', cls.ca, '-CAkey', cls.ca_key, '-set_serial', version, '-days', '2', '-extfile', extensions, '-out', cert)
            cls.certificates[version] = (cert, key)
        cls.expected = hashlib.sha256(ssl.PEM_cert_to_DER_cert(cls.certificates['2'][0].read_text())).hexdigest()

    @classmethod
    def tearDownClass(cls): cls.temporary.cleanup()

    def observe(self, version='2', hostname='one.example.test', trusted=True, min_days=1):
        with server(*self.certificates[version]) as port:
            return probe.observe(hostname, self.expected, min_days, port=port, connect_to='127.0.0.1', cafile=str(self.ca) if trusted else None)

    def test_replacement_certificate_is_accepted_over_real_tls(self):
        self.assertEqual(self.observe()['sha256'], self.expected)

    def test_old_certificate_is_rejected_even_with_a_valid_chain(self):
        with self.assertRaisesRegex(probe.ProbeError, 'fingerprint'): self.observe(version='1')

    def test_wrong_hostname_and_untrusted_ca_fail_real_handshakes(self):
        for kwargs in [{'hostname': 'two.example.test'}, {'trusted': False}]:
            with self.subTest(kwargs=kwargs), self.assertRaises(ssl.SSLCertVerificationError): self.observe(**kwargs)

    def test_short_validity_is_rejected_after_successful_handshake(self):
        with self.assertRaisesRegex(probe.ProbeError, 'validity'): self.observe(min_days=7)

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

path = Path(__file__).resolve().parents[1]/'scripts/build_artifacts.py'
spec = importlib.util.spec_from_file_location('artifacts', path)
artifacts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifacts)

class ArtifactTests(unittest.TestCase):
    def test_demo_package_has_an_importable_application_at_zip_root(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = [Path(directory)/name for name in ['one.zip', 'two.zip']]
            artifacts.demo_zip(first)
            artifacts.demo_zip(second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as archive:
                self.assertEqual(archive.namelist(), ['app.py'])
                namespace = {}
                exec(compile(archive.read('app.py'), 'app.py', 'exec'), namespace)
                for name in ['one', 'two']:
                    with self.subTest(application=name), patch.dict(os.environ, {'LAB_APP_NAME': name}):
                        statuses = []
                        body = namespace['app']({}, lambda status, headers: statuses.append(status))
                        self.assertEqual(statuses, ['200 OK'])
                        self.assertEqual(body, [('TLS renewal lab application: ' + name + '\n').encode()])

    def test_verifier_wrapper_is_shell_valid_without_executing_cloud_code(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)/'verifier.sh'
            artifacts.verifier_script(output, 'https://kv-example.vault.azure.net/', 'app-one', 'synthetic-client')
            self.assertEqual(subprocess.run(['sh', '-n', str(output)], capture_output=True).returncode, 0)
            with self.assertRaises(FileExistsError):
                artifacts.verifier_script(output, 'https://kv-example.vault.azure.net/', 'app-one', 'synthetic-client')

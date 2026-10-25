#!/usr/bin/env python3
"""Check owned source for accidental key custody and syntax/link drift."""
import ast
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
failures = []
files = [p for p in root.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
for path in files:
    if path.suffix == '.py':
        ast.parse(path.read_text(), filename=str(path))
    if path.suffix in {'.tfstate', '.tfplan', '.pfx', '.pem', '.key', '.zip'}:
        failures.append(str(path.relative_to(root)) + ': operational artifact in source')
    if path.suffix == '.tf':
        text = path.read_text()
        if re.search(r'(?:data|resource)\s+"(?:azurerm_key_vault_secret|azurerm_key_vault_certificate|tls_private_key)"', text):
            failures.append(str(path.relative_to(root)) + ': certificate/private material would enter Terraform')
for stack in ['bootstrap', 'foundation', 'edge']:
    text = (root/stack/'.terraform.lock.hcl').read_text()
    if 'version     = "4.81.0"' not in text:
        failures.append(stack + ': reviewed provider lock missing')
if 'version     = "3.7.0"' not in (root/'identity/.terraform.lock.hcl').read_text():
    failures.append('identity: reviewed provider lock missing')
lock = json.loads((root/'upstream.lock.json').read_text())
if 'latest' in lock['url'] or not re.fullmatch('[a-f0-9]{64}', lock['sha256']):
    failures.append('issuer release must have an exact version and digest')
for failure in failures: print(failure)
print(json.dumps({'status': 'failed' if failures else 'passed', 'source_files_checked': len(files)}))
raise SystemExit(bool(failures))

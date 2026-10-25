#!/usr/bin/env python3
"""Offline-container suite; emit minimal JUnit for the bounded evidence runner."""
import argparse
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--junit', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
suite = unittest.TestSuite([
    unittest.defaultTestLoader.discover(str(root/'tests')),
    unittest.defaultTestLoader.discover(str(root/'integration'), top_level_dir=str(root/'integration')),
])
result = unittest.TextTestRunner(verbosity=2).run(suite)
xml = ET.Element('testsuite', tests=str(result.testsRun), failures=str(len(result.failures)), errors=str(len(result.errors)), skipped=str(len(result.skipped)))
for test, _ in result.failures: ET.SubElement(ET.SubElement(xml, 'testcase', name=test.id()), 'failure')
for test, _ in result.errors: ET.SubElement(ET.SubElement(xml, 'testcase', name=test.id()), 'error')
ET.ElementTree(xml).write(args.junit, encoding='utf-8', xml_declaration=True)
raise SystemExit(not result.wasSuccessful())

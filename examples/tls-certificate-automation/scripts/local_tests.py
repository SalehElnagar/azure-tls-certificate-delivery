#!/usr/bin/env python3
"""Run credential-free Python tests from this frozen source tree."""
from pathlib import Path
import sys
import unittest

suite = unittest.defaultTestLoader.discover(str(Path(__file__).resolve().parents[1] / 'tests'))
raise SystemExit(not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful())

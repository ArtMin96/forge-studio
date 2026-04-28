#!/usr/bin/env python3
"""Validates that .claude-plugin/marketplace.json parses and reports plugin count."""
import json
import sys

try:
    data = json.load(open('.claude-plugin/marketplace.json'))
    print('PARSE: OK')
    print('PLUGIN_COUNT:', len(data.get('plugins', [])))
except Exception as e:
    print('PARSE: FAIL -', e)
    sys.exit(1)

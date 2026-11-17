# -*- coding: utf-8 -*-
"""Compiles each Lua file given, so a syntax error never ships again.

Needs lupa (pip install lupa). Without it, falls back to check_strings.py,
which only catches a quoted string left open at the end of a line.

    python tools/check_lua.py Locales.lua MyXPBar.lua Options.lua ...
"""
import io
import os
import subprocess
import sys

try:
    import lupa
except ImportError:
    here = os.path.dirname(os.path.abspath(__file__))
    print('lupa not installed: falling back to the string check')
    sys.exit(subprocess.call([sys.executable, os.path.join(here, 'check_strings.py')] + sys.argv[1:]))

runtime = lupa.LuaRuntime()
bad = 0
for path in sys.argv[1:]:
    source = io.open(path, encoding='utf-8').read()
    try:
        runtime.compile(source)
        print('OK   %s' % path)
    except Exception as error:
        bad += 1
        print('FAIL %s: %s' % (path, error))
sys.exit(1 if bad else 0)

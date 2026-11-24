# -*- coding: utf-8 -*-
"""Runs tools/simulate.lua with lupa, from the root of the addon.

    python tools/run_simulate.py
"""
import io
import os
import sys

try:
    import lupa
except ImportError:
    print('lupa is not installed: pip install lupa')
    sys.exit(2)

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
os.chdir(root)

runtime = lupa.LuaRuntime(unpack_returned_tuples=True)
printed = []
runtime.globals().print = lambda *parts: printed.append(' '.join(str(p) for p in parts))
source = io.open(os.path.join(here, 'simulate.lua'), encoding='utf-8').read()
chunk = runtime.eval('function(src, dir) return load(src, "simulate")(dir) end')
try:
    chunk(source, here.replace(os.sep, '/'))
except lupa.LuaError as error:
    print('the run itself blew up: %s' % error)
    sys.exit(1)

for line in printed:
    print(line)
sys.exit(0 if any(line.startswith('RESULT ok') for line in printed) else 1)

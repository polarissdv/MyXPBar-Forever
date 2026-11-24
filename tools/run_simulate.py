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
runtime.execute('os.exit = function(code) error({ exit = code or 0 }, 0) end')
source = io.open(os.path.join(here, 'simulate.lua'), encoding='utf-8').read()
chunk = runtime.eval('function(src, dir) return load(src, "simulate")(dir) end')
try:
    chunk(source, here.replace(os.sep, '/'))
except lupa.LuaError as error:
    text = str(error)
    if 'exit = 0' in text or 'exit' not in text:
        pass
    print(text)
    sys.exit(0 if 'exit = 0' in text else 1)
sys.exit(0)

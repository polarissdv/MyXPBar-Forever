# -*- coding: utf-8 -*-
"""Reports Lua quoted strings left open at the end of a line.
Catches an unescaped quote inside a "..." literal, which is a syntax error."""
import io, sys

BS = chr(92)
bad = 0
for path in sys.argv[1:]:
    text = io.open(path, encoding='utf-8').read()
    for n, line in enumerate(text.split('\n'), 1):
        i, q, longq = 0, None, False
        while i < len(line):
            c = line[i]
            if q:
                if c == BS:
                    i += 2
                    continue
                if c == q:
                    q = None
            elif c in '"\'':
                q = c
            elif line[i:i+2] == '--':
                if line[i:i+4] == '--[[':
                    longq = True
                break
            elif line[i:i+2] == '[[':
                longq = True
                break
            i += 1
        if q and not longq:
            bad += 1
            print('%s:%d: string left open -> %s' % (path, n, line.strip()[:90]))
print('open strings found:', bad)
sys.exit(1 if bad else 0)

#!/usr/bin/env python3
"""Lists tr('...') and trData('...') keys in Dart files that have no Hindi
translation in any lib/l10n/hi/*.dart map.

Usage: python3 tool/check_hi.py lib/screens/patient/today_screen.dart [...]
"""
import glob, re, sys, os

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def unescape(s):
    return s.replace("\\'", "'").replace('\\"', '"').replace('\\$', '$').replace('\\n', '\n')

lit = r"(?:'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\")"
keys = set()
for f in glob.glob(os.path.join(root, 'lib/l10n/hi/*.dart')):
    src = open(f, encoding='utf-8').read()
    for m in re.finditer(r"^\s*" + lit + r"\s*:", src, re.M):
        keys.add(unescape(m.group(1) if m.group(1) is not None else m.group(2)))

missing = 0
for f in sys.argv[1:]:
    src = open(f, encoding='utf-8').read()
    for m in re.finditer(r"\b(?:tr|trData)\(\s*" + lit, src):
        raw = m.group(1) if m.group(1) is not None else m.group(2)
        k = unescape(raw)
        if re.search(r'(?<!\\)\$', raw):
            print(f'{f}: key uses Dart interpolation, use {{placeholders}}: {k!r}')
            missing += 1
        elif k not in keys:
            print(f'{f}: missing: {k!r}')
            missing += 1
print(f'{missing} problem(s)')
sys.exit(1 if missing else 0)

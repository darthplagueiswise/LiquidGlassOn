#!/usr/bin/env python3
from pathlib import Path
import collections
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []

SOURCE_EXTS = {'.m', '.h', '.x', '.xm', '.mm', '.c'}
TEXT_EXTS = SOURCE_EXTS | {'.md', '.sh', '.yml', '.yaml', '.plist', '.txt', '.json', '.gitignore', '.clangd'}

# 1. No extern "C" in Objective-C-only sources.
for p in list((ROOT / 'src').rglob('*.m')) + list((ROOT / 'src').rglob('*.x')):
    s = p.read_text(errors='ignore')
    if 'extern "C"' in s:
        errors.append(f'{p.relative_to(ROOT)}: extern "C" is invalid in .m/.x')

# 2. No missing local imports.
for p in [x for x in (ROOT / 'src').rglob('*') if x.suffix in SOURCE_EXTS]:
    s = p.read_text(errors='ignore')
    for inc in re.findall(r'#import\s+"([^"]+)"', s):
        candidates = [p.parent / inc, ROOT / 'src' / inc, ROOT / inc]
        if not any(c.exists() for c in candidates):
            errors.append(f'{p.relative_to(ROOT)}: missing import {inc}')

# 3. WAGramMenuVC.h must own the primary browser interfaces.
h = ROOT / 'src/Menu/WAGramMenuVC.h'
if not h.exists():
    errors.append('src/Menu/WAGramMenuVC.h missing')
else:
    hs = h.read_text(errors='ignore')
    required = [
        '@interface WAGRABFlagBrowserVC :',
        '@interface WAGRWAABTriStateBrowserVC :',
        '@interface WAGramBundleVC :',
        '@interface WAGramMenuVC :',
        '@interface WAGramWAABRuntimeCategoriesVC :',
        '@interface WAGRRuntimeMethodBrowserVC :',
    ]
    for token in required:
        if token not in hs:
            errors.append(f'src/Menu/WAGramMenuVC.h missing primary interface: {token}')

# 4. Compatibility headers must not redefine classes.
for rel in ['src/Menu/WAGRRuntimeMethodBrowserVC.h', 'src/Menu/WAGramWAABRuntimeCategoriesVC.h']:
    p = ROOT / rel
    if not p.exists():
        errors.append(f'{rel} missing')
        continue
    s = p.read_text(errors='ignore')
    if '@interface WAGRRuntimeMethodBrowserVC' in s or '@interface WAGramWAABRuntimeCategoriesVC' in s:
        errors.append(f'{rel}: compatibility header must not redefine interfaces')

# 5. Duplicate WAGR/WAGram class implementations.
primary_interfaces = collections.defaultdict(list)
implementations = collections.defaultdict(list)
for p in [x for x in (ROOT / 'src').rglob('*') if x.suffix in SOURCE_EXTS]:
    s = p.read_text(errors='ignore')
    for m in re.finditer(r'@interface\s+([A-Za-z_][A-Za-z0-9_]*)\s*:', s):
        name = m.group(1)
        if name.startswith(('WAGR', 'WAGram')):
            primary_interfaces[name].append(str(p.relative_to(ROOT)))
    for m in re.finditer(r'@implementation\s+([A-Za-z_][A-Za-z0-9_]*)\b', s):
        name = m.group(1)
        if name.startswith(('WAGR', 'WAGram')):
            implementations[name].append(str(p.relative_to(ROOT)))

for name, files in primary_interfaces.items():
    unique = sorted(set(files))
    if len(unique) > 1:
        errors.append(f'duplicate primary interface {name}: {unique}')
for name, files in implementations.items():
    unique = sorted(set(files))
    if len(unique) > 1:
        errors.append(f'duplicate implementation {name}: {unique}')

# 6. Runtime categories must use a distinct local tri-state browser.
rt = ROOT / 'src/Menu/WAGramWAABRuntimeCategoriesVC.m'
if rt.exists():
    s = rt.read_text(errors='ignore')
    if '@interface WAGRWAABTriStateBrowserVC' in s or '@implementation WAGRWAABTriStateBrowserVC' in s:
        errors.append('WAGramWAABRuntimeCategoriesVC.m redefines WAGRWAABTriStateBrowserVC')
    if 'WAGRWAABRuntimeTriStateBrowserVC' not in s:
        errors.append('WAGramWAABRuntimeCategoriesVC.m missing WAGRWAABRuntimeTriStateBrowserVC')

# 7. Startup guard tokens for heavy hook families.
for rel in ['src/Hooks/WAABPropsObserver.xm', 'src/Hooks/WAGramBundleHooks.xm', 'src/Hooks/WAEmployeeDogfoodHooks.xm']:
    p = ROOT / rel
    if not p.exists():
        errors.append(f'{rel} missing')
    elif 'inert startup; hooks install only from menu/toggle' not in p.read_text(errors='ignore'):
        errors.append(f'{rel}: missing safe-startup guard')

# 8. DebugBuild broad hook must be conditional.
t = ROOT / 'src/Tweak.x'
if t.exists():
    s = t.read_text(errors='ignore')
    for m in re.finditer(r'WAGRDebugBuildEnsureHooksInstalled\(\);', s):
        context = s[max(0, m.start() - 180):m.start()]
        if 'extern ' in context:
            continue
        if 'wagr_simulate_debug_build' not in context:
            errors.append('src/Tweak.x: unconditional WAGRDebugBuildEnsureHooksInstalled()')

# 9. Whitespace checks similar to git diff --check.
for p in ROOT.rglob('*'):
    if not p.is_file() or '.git' in p.parts or p.suffix == '.gz':
        continue
    try:
        text = p.read_text()
    except Exception:
        continue
    rel = p.relative_to(ROOT)
    for idx, line in enumerate(text.splitlines(), 1):
        if line.rstrip() != line:
            errors.append(f'{rel}:{idx}: trailing whitespace')
    lines = text.splitlines()
    if lines and lines[-1] == '':
        errors.append(f'{rel}: blank line at EOF')


# 10. Categories must not implement methods already advertised by the primary
# interface in this tree. With -Werror, Clang turns this into a hard build
# failure (-Wobjc-protocol-method-implementation). Put the method in the
# primary @implementation instead, or do not declare it on the primary class.
method_pat = re.compile(r'[-+]\s*\([^)]*\)\s*([A-Za-z_][A-Za-z0-9_]*)(?=\s*[:;{])')
interfaces = collections.defaultdict(set)
category_impls = []

for p in [x for x in (ROOT / 'src').rglob('*') if x.suffix in SOURCE_EXTS]:
    src = p.read_text(errors='ignore')
    for m in re.finditer(r'@interface\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:\([^)]*\))?\s*:', src):
        cls = m.group(1)
        end = src.find('@end', m.end())
        if end == -1:
            continue
        block = src[m.end():end]
        for mm in method_pat.finditer(block):
            interfaces[cls].add(mm.group(1))
    for m in re.finditer(r'@implementation\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)', src):
        cls = m.group(1)
        end = src.find('@end', m.end())
        if end == -1:
            continue
        block = src[m.end():end]
        for mm in method_pat.finditer(block):
            category_impls.append((cls, mm.group(1), p.relative_to(ROOT)))

for cls, method, rel in category_impls:
    if method in interfaces.get(cls, set()):
        errors.append(f'{rel}: category implements {cls}.{method} also declared by primary interface')

# 11. Specific guard for the flag browser reset selector. If the WAAB browser
# calls [self confirmNuclearReset], that selector must be declared privately
# and implemented in the WAGRABFlagBrowserVC primary implementation, not in a
# separate category file.
menu = ROOT / 'src/Menu/WAGramMenuVC.m'
if menu.exists():
    ms = menu.read_text(errors='ignore')
    if '[self confirmNuclearReset]' in ms:
        ext = re.search(r'@interface\s+WAGRABFlagBrowserVC\s*\(\)(.*?)@end', ms, re.S)
        impl = re.search(r'@implementation\s+WAGRABFlagBrowserVC\b(.*?)@end', ms, re.S)
        if not ext or '- (void)confirmNuclearReset;' not in ext.group(1):
            errors.append('src/Menu/WAGramMenuVC.m: WAGRABFlagBrowserVC calls confirmNuclearReset without private declaration')
        if not impl or '- (void)confirmNuclearReset' not in impl.group(1):
            errors.append('src/Menu/WAGramMenuVC.m: WAGRABFlagBrowserVC calls confirmNuclearReset without primary implementation')

if errors:
    print('\n'.join('ERRO: ' + e for e in errors), file=sys.stderr)
    sys.exit(1)
print('OK: WAGram source validation passed')

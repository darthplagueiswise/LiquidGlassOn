#!/bin/sh
set -eu

REPO="${REPO:-/root/LiquidGlassOn}"
ZIP="${ZIP:-/root/LiquidGlassOn-v7.zip}"
BRANCH="${BRANCH:-dev4}"
BASE="${BASE:-d4ae04bfe948e08167bda636e31715e57198a6a1}"

test -f "$ZIP" || { echo "ERRO: zip não encontrado: $ZIP"; exit 1; }
test -d "$REPO/.git" || { echo "ERRO: repo não encontrado: $REPO"; exit 1; }

cd "$REPO"
git fetch origin --prune
git checkout -B "$BRANCH" "$BASE"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
unzip -q "$ZIP" -d "$TMP"
SRC="$(find "$TMP" -type f -name Makefile -exec dirname {} \; | head -1)"
test -n "$SRC" || { echo "ERRO: raiz do projeto não encontrada no zip"; exit 1; }

find "$REPO" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$SRC"/. "$REPO"/

python3 - <<'PY'
from pathlib import Path
import re
for p in Path('.github/workflows').glob('*'):
    if p.suffix not in ('.yml', '.yaml'):
        continue
    s = p.read_text()
    s = re.sub(r"- 'dev\d*'|- 'dev'", "- 'dev4'", s)
    s = s.replace('Build WAGram dev3', 'Build WAGram dev4')
    s = s.replace('Build WAGram dev2', 'Build WAGram dev4')
    s = s.replace('Build WAGram dev', 'Build WAGram dev4')
    p.write_text(s)

m = Path('src/Menu/WAGramMenuVC.m')
s = m.read_text()
if '[[self.navigationController]' in s:
    raise SystemExit('ERRO: syntax ruim [[self.navigationController]')
if 'static const char kMasterKey = 0' in s:
    raise SystemExit('ERRO: kMasterKey ainda existe')
if re.search(r'hasPrefix:@"wagr\."\s*\|\|', s):
    raise SystemExit('ERRO: hasPrefix:@"wagr." com || dentro do argumento')
if '[ud setObject:@"off" forKey:WAGRKey(f)]' not in s:
    raise SystemExit('ERRO: FlagSet não grava "off"')
PY

chmod +x build.sh build-dev.sh build-fast.sh 2>/dev/null || true
find . -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

git diff --check
git add -A
git status --short

if git diff --cached --quiet; then
  git commit --allow-empty -m "Trigger dev4 build"
else
  git commit -m "Import revised LiquidGlassOn dev4"
fi

git push -u origin HEAD:"$BRANCH"

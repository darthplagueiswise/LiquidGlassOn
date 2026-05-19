#!/bin/sh
set -eu
REPO="${REPO:-/root/LiquidGlassOn}"
ZIP="${ZIP:-/root/LiquidGlassOn-wagr-v10-dev5-nuclear-reset.zip}"
BRANCH="${BRANCH:-dev5}"
[ -d "$REPO/.git" ] || { echo "ERRO: repo não encontrado: $REPO" >&2; exit 1; }
[ -f "$ZIP" ] || { echo "ERRO: zip não encontrado: $ZIP" >&2; exit 1; }
cd "$REPO"
git fetch origin --prune || true
if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then git checkout "$BRANCH"; else git checkout -b "$BRANCH" "origin/$BRANCH"; fi
git reset --hard "origin/$BRANCH"
git clean -fd
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$ZIP" -d "$TMP"
SRC="$(find "$TMP" -maxdepth 4 -type f -name Makefile -exec dirname {} \; | head -n 1)"
[ -n "$SRC" ] || { echo "ERRO: Makefile não encontrado no zip" >&2; exit 1; }
find "$REPO" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$SRC"/. "$REPO"/
python3 scripts/wagr_validate_sources.py
git diff --check
git add -A
git commit -m "WAGram v10: add nuclear NSUserDefaults reset and safe toggles" || true
git push origin "$BRANCH"

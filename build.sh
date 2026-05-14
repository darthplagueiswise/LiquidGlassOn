#!/usr/bin/env bash
# build.sh — build WAGram tweak (normal device install)
set -euo pipefail

cd "$(dirname "$0")"

echo "[WAGram] Building..."
make package FINALPACKAGE=1 "$@"
echo "[WAGram] Done."

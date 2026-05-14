#!/usr/bin/env bash
# build-sideload.sh — build WAGram as a sideload dylib (SIDESTORE + SideloadPatch)
set -euo pipefail

cd "$(dirname "$0")"

echo "[WAGram] Building sideload variant..."
make package FINALPACKAGE=1 SIDESTORE=1 "$@"
echo "[WAGram] Sideload build done."

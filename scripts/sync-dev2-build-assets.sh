#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/.vendor/Ryukgram-Fork"

mkdir -p "$ROOT/modules/fishhook"

if [ ! -d "$VENDOR/.git" ]; then
  mkdir -p "$ROOT/.vendor"
  git clone --depth 1 --branch dev2 https://github.com/darthplagueiswise/Ryukgram-Fork.git "$VENDOR"
else
  git -C "$VENDOR" fetch --depth 1 origin dev2
  git -C "$VENDOR" checkout dev2
  git -C "$VENDOR" reset --hard origin/dev2
fi

cp -f "$VENDOR/modules/fishhook/fishhook.c" "$ROOT/modules/fishhook/fishhook.c"
cp -f "$VENDOR/modules/fishhook/fishhook.h" "$ROOT/modules/fishhook/fishhook.h"

echo "[LiquidGlassOn] synced fishhook from Ryukgram-Fork/dev2"

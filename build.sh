#!/usr/bin/env bash
set -euo pipefail

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
OUT="LiquidGlassOn.dylib"

clang -arch arm64 \
  -isysroot "$SDK" \
  -miphoneos-version-min=14.0 \
  -dynamiclib -fobjc-arc \
  -framework Foundation \
  -o "$OUT" src/LiquidGlassOn.m

echo "Built $OUT"

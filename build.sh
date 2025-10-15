#!/usr/bin/env bash
set -euo pipefail

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
OUT=build/LiquidGlassOn.dylib

mkdir -p build
xcrun --sdk iphoneos clang \
  -arch arm64 \
  -miphoneos-version-min=14.0 \
  -fobjc-arc \
  -isysroot "$SDK" \
  -dynamiclib \
  -install_name @rpath/LiquidGlassOn.dylib \
  -framework Foundation \
  -framework UIKit \
  -o "$OUT" \
  src/LiquidGlassOn.m

strip -S "$OUT"
otool -l "$OUT" | sed -n '/LC_ID_DYLIB/,/name/p'
echo "Built $OUT"

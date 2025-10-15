#!/usr/bin/env bash
set -euo pipefail
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
mkdir -p build
xcrun --sdk iphoneos clang \
  -arch arm64 -miphoneos-version-min=14.0 -fobjc-arc -isysroot "$SDK" \
  -dynamiclib -install_name @rpath/LiquidGlassOn.dylib \
  -framework Foundation -framework UIKit \
  -o build/LiquidGlassOn.dylib src/LiquidGlassOn.m
strip -S build/LiquidGlassOn.dylib
otool -l build/LiquidGlassOn.dylib | sed -n '/LC_ID_DYLIB/,/name/p'
echo "Built build/LiquidGlassOn.dylib"

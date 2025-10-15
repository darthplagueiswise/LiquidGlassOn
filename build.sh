#!/usr/bin/env bash

# Exit immediately on error and treat unset variables as an error
set -euo pipefail

# Determine the path to the iOS SDK for compiling against the iPhoneOS platform
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"

# Name of the output dynamic library
OUT="LiquidGlassOn.dylib"

# Compile the Objective‑C source file into a dynamic library for arm64
clang -arch arm64 \
  -isysroot "$SDK" \
  -miphoneos-version-min=14.0 \
  -dynamiclib -fobjc-arc \
  -install_name "@rpath/LiquidGlassOn.dylib" \
  -current_version 1.0 \
  -compatibility_version 1.0 \
  -framework Foundation \
  -framework UIKit \
  src/LiquidGlassOn.m \
  -o "$OUT"

echo "Built $OUT"
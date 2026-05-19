#!/usr/bin/env bash
# build-dev.sh — fast dev loop for LiquidGlassOn
# Adapted from RyukGram-Fork/dev2/build-dev.sh

set -e

if [ -z "$THEOS" ]; then
	if [ -d "$HOME/theos" ]; then export THEOS="$HOME/theos"
	else echo -e '\033[1m\033[0;31mTHEOS not set and ~/theos not found.\033[0m' >&2; exit 1; fi
fi

echo 'Note: This script is for quick dev iteration.'
echo '      Use ./build.sh rootless / sideload / etc. for release builds.'
echo

# Fast incremental build + deploy via install_name_tool fixup
make clean
make DEV=1

install_name_tool \
	-change "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate" \
	"@rpath/CydiaSubstrate.framework/CydiaSubstrate" \
	".theos/obj/debug/LiquidGlassOn.dylib" 2>/dev/null || true

echo -e "\033[1m\033[32mDev build done.\033[0m"
echo "Dylib at: $(pwd)/.theos/obj/debug/LiquidGlassOn.dylib"

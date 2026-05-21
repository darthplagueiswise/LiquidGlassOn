#!/usr/bin/env bash
# build-fast.sh — reuse prebuilt dylib, only repackage the IPA
# Adapted from RyukGram-Fork/dev2/build-fast.sh
#
# Pre-req:  ./build.sh dylib      (produces packages/WATweaks.dylib)
# Then:     ./build-fast.sh       (or ./build-fast.sh sidestore)

set -e

if [ -z "$THEOS" ]; then
	if [ -d "$HOME/theos" ]; then export THEOS="$HOME/theos"
	else echo -e '\033[1m\033[0;31mTHEOS not set.\033[0m' >&2; exit 1; fi
fi

OUT_IPA="packages/WATweaks-sideloaded-debug.ipa"
COMPRESSION=9

# ── arg parse ────────────────────────────────────────────────────────────────
MODE="sideload"
for arg in "$@"; do
	case "$arg" in
		sidestore) MODE="sidestore" ;;
		sideload|"") ;;
		*) echo "unknown arg: $arg" >&2; exit 1 ;;
	esac
done

if [ "$MODE" = "sidestore" ]; then
	OUT_IPA="packages/WATweaks-sidestore-debug.ipa"
fi

# ── pre-req checks ────────────────────────────────────────────────────────────
if [ ! -f "packages/WATweaks.dylib" ]; then
	echo -e '\033[1m\033[0;31mpackages/WATweaks.dylib missing.\033[0m'
	echo -e '\033[0;33mRun ./build.sh dylib first.\033[0m'
	exit 1
fi

if ! command -v cyan &> /dev/null; then
	echo -e '\033[1m\033[0;31mcyan not found.\033[0m'
	echo 'Install: pip install --force-reinstall https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip'
	exit 1
fi

# ── find WA IPA ───────────────────────────────────────────────────────────────
mkdir -p packages
ipaFile="$(find ./packages/ -maxdepth 1 -type f \( \
	-iname '*net.whatsapp.WhatsApp*.ipa' -o \
	-iname 'WhatsApp*.ipa' -o \
	-iname '[0-9]*.ipa' \
\) ! -iname 'WATweaks*.ipa' -exec basename {} \; 2>/dev/null | head -1)"

if [ -z "${ipaFile}" ]; then
	cwdIpa="$(find . -maxdepth 1 -type f \( \
		-iname '*net.whatsapp.WhatsApp*.ipa' -o \
		-iname 'WhatsApp*.ipa' \
	\) 2>/dev/null | head -1)"
	if [ -n "$cwdIpa" ]; then
		mv "$cwdIpa" packages/
		ipaFile="$(basename "$cwdIpa")"
	fi
fi

if [ -z "${ipaFile}" ]; then
	echo -e '\033[1m\033[0;31mDecrypted WhatsApp IPA not found.\033[0m'
	exit 1
fi

# ── cyan inject ───────────────────────────────────────────────────────────────
echo -e '\033[1m\033[32mPackaging IPA (cyan)\033[0m'
rm -f "$OUT_IPA"
cyan -i "packages/${ipaFile}" \
	-o "$OUT_IPA" \
	-f packages/WATweaks.dylib \
	-c $COMPRESSION \
	-m 16.0 \
	-du

echo -e "\033[1m\033[32mDone!\033[0m\n\nIPA at: $(pwd)/$OUT_IPA"

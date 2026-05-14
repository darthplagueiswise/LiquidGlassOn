#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[1m\033[32m'
YELLOW='\033[0;33m'
RED='\033[1m\033[0;31m'
RESET='\033[0m'

APP_NAME="WAGram"
PACKAGES_DIR="packages"

log() { printf "%b\n" "${GREEN}$*${RESET}"; }
warn() { printf "%b\n" "${YELLOW}$*${RESET}"; }
die() { printf "%b\n" "${RED}$*${RESET}" >&2; exit 1; }

ensure_theos() {
	if [ -n "${THEOS:-}" ]; then return; fi
	if [ -d "$HOME/theos" ]; then export THEOS="$HOME/theos"; else die "THEOS not set and ~/theos not found."; fi
}

ensure_packages_dir() { mkdir -p "$PACKAGES_DIR"; }

log "[WAGram] Starting complete build..."
ensure_theos
ensure_packages_dir

make clean || true
make package FINALPACKAGE=1

DEB=$(ls -t packages/*.deb 2>/dev/null | head -n1 || echo "")
if [ -n "$DEB" ]; then
	log "[WAGram] Package created: $DEB"
else
	warn "[WAGram] No .deb found — check Theos output above"
	exit 1
fi

log "[WAGram] Build finished successfully!"
#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# WALiquidGlassRyuk Build Script (based on RyukGram-Fork/dev2)
# ============================================================

GREEN='\033[1m\033[32m'
YELLOW='\033[0;33m'
RED='\033[1m\033[0;31m'
RESET='\033[0m'

APP_NAME="WALiquidGlassRyuk"
PACKAGES_DIR="packages"

log() {
	printf "%b\n" "${GREEN}$*${RESET}"
}

warn() {
	printf "%b\n" "${YELLOW}$*${RESET}"
}

die() {
	printf "%b\n" "${RED}$*${RESET}" >&2
	exit 1
}

ensure_theos() {
	if [ -n "${THEOS:-}" ]; then
		return
	fi

	if [ -d "$HOME/theos" ]; then
		export THEOS="$HOME/theos"
	else
		die "THEOS not set and ~/theos not found.\nSet THEOS or install Theos to ~/theos"
	fi
}

ensure_packages_dir() {
	mkdir -p "$PACKAGES_DIR"
}

clean_build() {
	make clean 2>/dev/null || true
	rm -rf .theos
}

make_final() {
	local args="${1:-}"

	if [ -n "$args" ]; then
		make FINALPACKAGE=1 $args
	else
		make FINALPACKAGE=1
	fi
}

# Main build
ensure_theos
ensure_packages_dir

log "Building $APP_NAME (based on RyukGram-Fork/dev2)"

make_final "$@"

log "Build complete! Check packages/"
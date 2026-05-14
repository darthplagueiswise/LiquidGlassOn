#!/usr/bin/env bash
# ============================================================
# LiquidGlassOn Build Script
# Ported from RyukGram-Fork/dev2/build.sh — adapted for WhatsApp
# ============================================================

set -euo pipefail

GREEN='\033[1m\033[32m'
YELLOW='\033[0;33m'
RED='\033[1m\033[0;31m'
RESET='\033[0m'

APP_NAME="LiquidGlassOn"
PACKAGES_DIR="packages"
TWEAK_DYLIB=".theos/obj/${APP_NAME}.dylib"

log()  { printf "%b\n" "${GREEN}$*${RESET}"; }
warn() { printf "%b\n" "${YELLOW}$*${RESET}"; }
die()  { printf "%b\n" "${RED}$*${RESET}" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "$2"; }

ensure_theos() {
	if [ -n "${THEOS:-}" ]; then return; fi
	if [ -d "$HOME/theos" ]; then
		export THEOS="$HOME/theos"
	else
		die "THEOS not set and ~/theos not found.\nSet THEOS or install Theos to ~/theos"
	fi
}

ensure_packages_dir() { mkdir -p "$PACKAGES_DIR"; }

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

# ── Find decrypted WhatsApp IPA ────────────────────────────────────────────────
find_whatsapp_ipa() {
	local ipa_file=""
	local cwd_ipa=""

	ensure_packages_dir

	ipa_file="$(find "./${PACKAGES_DIR}" -maxdepth 1 -type f \( \
		-iname '*net.whatsapp.WhatsApp*.ipa' -o \
		-iname 'WhatsApp*.ipa' -o \
		-iname '[0-9]*.ipa' \
	\) ! -iname "${APP_NAME}*.ipa" -exec basename {} \; 2>/dev/null | head -1)"

	if [ -n "$ipa_file" ]; then
		printf "%s\n" "$ipa_file"
		return 0
	fi

	cwd_ipa="$(find . -maxdepth 1 -type f \( \
		-iname '*net.whatsapp.WhatsApp*.ipa' -o \
		-iname 'WhatsApp*.ipa' -o \
		-iname '[0-9]*.ipa' \
	\) 2>/dev/null | head -1)"

	if [ -n "$cwd_ipa" ]; then
		log "Moving $(basename "$cwd_ipa") → ${PACKAGES_DIR}/" >&2
		mv "$cwd_ipa" "$PACKAGES_DIR/"
		printf "%s\n" "$(basename "$cwd_ipa")"
		return 0
	fi

	return 1
}

# ── Build dylib only ──────────────────────────────────────────────────────────
build_dylib() {
	local option="${1:-}"

	if [ "$option" != "--fast" ]; then
		clean_build
	fi

	log "Building ${APP_NAME} dylib"

	make_final ""

	ensure_packages_dir
	cp "$TWEAK_DYLIB" "${PACKAGES_DIR}/${APP_NAME}.dylib"

	log "Done!"
	echo
	echo "Dylib at: $(pwd)/${PACKAGES_DIR}/${APP_NAME}.dylib"
}

# ── Build sideloaded IPA ──────────────────────────────────────────────────────
build_sideload() {
	local mode="${1:-sideload}"
	local option="${2:-}"

	local out_ipa="${PACKAGES_DIR}/${APP_NAME}-sideloaded.ipa"
	local makeargs=""
	local compression=9

	if [ "$mode" = "sidestore" ]; then
		out_ipa="${PACKAGES_DIR}/${APP_NAME}-sidestore.ipa"
		makeargs="SIDESTORE=1"
		log "Building ${APP_NAME} for SideStore"
	else
		log "Building ${APP_NAME} for sideload"
	fi

	clean_build
	ensure_packages_dir

	local ipa_file
	ipa_file="$(find_whatsapp_ipa)" || die "Decrypted WhatsApp IPA not found.\nPlace a WhatsApp*.ipa in ./ or ./packages/."

	if [ "$option" != "--buildonly" ]; then
		need_cmd cyan "cyan not found. Install with:\n  pip install --force-reinstall https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip\n\nOr use: ./build.sh sideload --buildonly"
	fi

	make_final "$makeargs"

	cp "$TWEAK_DYLIB" "${PACKAGES_DIR}/${APP_NAME}.dylib"

	if [ "$option" = "--buildonly" ]; then
		log "Build-only finished."
		exit 0
	fi

	log "Creating the IPA (cyan)"

	rm -f "$out_ipa"

	cyan -i "${PACKAGES_DIR}/${ipa_file}" \
		-o "$out_ipa" \
		-f "${PACKAGES_DIR}/${APP_NAME}.dylib" \
		-c "$compression" \
		-m 16.0 \
		-du

	log "Done, enjoy ${APP_NAME}!"
	echo
	echo "IPA at: $(pwd)/$out_ipa"
}

# ── Build rootless/rootful .deb ────────────────────────────────────────────────
build_deb() {
	local scheme="$1"

	clean_build
	ensure_packages_dir

	if [ "$scheme" = "rootless" ]; then
		log "Building ${APP_NAME} tweak for rootless"
		export THEOS_PACKAGE_SCHEME=rootless
	else
		log "Building ${APP_NAME} tweak for rootful"
		unset THEOS_PACKAGE_SCHEME
	fi

	make_final "package"

	log "Done, enjoy ${APP_NAME}!"
	echo
	echo "Deb at: $(pwd)/${PACKAGES_DIR}"
}

# ── Build TrollStore .tipa ────────────────────────────────────────────────────
build_trollstore() {
	local ipa_file
	local out_ipa="${PACKAGES_DIR}/${APP_NAME}-trollstore.ipa"
	local out_tipa="${PACKAGES_DIR}/${APP_NAME}-trollstore.tipa"

	clean_build
	ensure_packages_dir

	ipa_file="$(find_whatsapp_ipa)" || die "Decrypted WhatsApp IPA not found."

	need_cmd cyan "cyan not found. Install with:\n  pip install --force-reinstall https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip"

	log "Building ${APP_NAME} tweak for TrollStore .tipa"

	make_final ""

	cp "$TWEAK_DYLIB" "${PACKAGES_DIR}/${APP_NAME}.dylib"

	log "Creating TIPA (cyan)"

	rm -f "$out_ipa" "$out_tipa"

	cyan -i "${PACKAGES_DIR}/${ipa_file}" \
		-o "$out_ipa" \
		-f "${PACKAGES_DIR}/${APP_NAME}.dylib" \
		-c 9 \
		-m 16.0 \
		-du

	mv "$out_ipa" "$out_tipa"

	log "Done!"
	echo
	echo "TIPA at: $(pwd)/$out_tipa"
}

# ── Build TrollFools zip ───────────────────────────────────────────────────────
build_trollfools() {
	clean_build
	ensure_packages_dir

	log "Building ${APP_NAME} tweak for TrollFools"

	make_final ""

	local stage
	stage="$(mktemp -d)"

	cp "$TWEAK_DYLIB" "$stage/${APP_NAME}.dylib"

	local out_zip="${PACKAGES_DIR}/${APP_NAME}-trollfools.zip"
	rm -f "$out_zip"
	( cd "$stage" && zip -qr -9 "$OLDPWD/$out_zip" . )
	rm -rf "$stage"

	log "Done!"
	echo
	echo "TrollFools zip at: $(pwd)/$out_zip"
}

usage() {
	echo '+-----------------------------+'
	echo '| LiquidGlassOn Build Script  |'
	echo '+-----------------------------+'
	echo
	echo "Usage: $0 <command> [option]"
	echo
	echo 'Commands:'
	echo '  dylib                Build the dylib only (for TrollFools / Feather)'
	echo '  dylib --fast         Build dylib without cleaning'
	echo '  sideload             Build a patched IPA (requires cyan + decrypted WA IPA)'
	echo '  sideload --buildonly Compile only, skip IPA creation'
	echo '  sidestore            Like sideload + SideloadPatch (keychain/app-group fixes)'
	echo '  trollstore           Build a .tipa for TrollStore'
	echo '  trollfools           Build a TrollFools zip'
	echo '  rootless             Build rootless .deb'
	echo '  rootful              Build rootful .deb'
	echo
	echo 'Place a decrypted WhatsApp.ipa in ./ or ./packages/ for sideload/trollstore builds.'
	exit 1
}

main() {
	ensure_theos

	local command="${1:-}"
	local option="${2:-}"

	case "$command" in
		dylib)      build_dylib "$option" ;;
		sideload)   build_sideload "sideload" "$option" ;;
		sidestore)  build_sideload "sidestore" "$option" ;;
		trollstore) build_trollstore ;;
		trollfools) build_trollfools ;;
		rootless)   build_deb "rootless" ;;
		rootful)    build_deb "rootful" ;;
		*) usage ;;
	esac
}

main "$@"

#!/usr/bin/env bash
# 20-extract-source.sh - Extract the upstream x64 .deb to retrieve the
# architecture-independent app resources and detect the bundled Electron version.
#
# Outputs:
#   build/source-extract/      full extracted deb tree
#   build/.electron-version    detected Electron version (e.g. 39.6.0)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

log_step "Stage 20: Extracting source .deb"

if [ ! -f "${BUILD_DIR}/.source-deb-path" ]; then
    log_error "Source .deb path not recorded. Run 10-fetch-source.sh first."
    exit 1
fi
DEB="$(cat "${BUILD_DIR}/.source-deb-path")"

EXTRACT_DIR="$(build_subdir source-extract)"

# Skip if already extracted and .deb hasn't changed
STAMP="${EXTRACT_DIR}/.stamp"
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$DEB" ]; then
    log_info "Already extracted; skipping (delete ${EXTRACT_DIR} to force re-extract)"
else
    log_info "Extracting $DEB -> $EXTRACT_DIR"
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    dpkg-deb -x "$DEB" "$EXTRACT_DIR"
    printf '%s' "$DEB" > "$STAMP"
fi

KIRO_BIN="${EXTRACT_DIR}/usr/share/kiro/kiro"
if [ ! -f "$KIRO_BIN" ]; then
    log_error "Expected Kiro binary not found at $KIRO_BIN"
    exit 1
fi

ELECTRON_VERSION="$(detect_electron_version "$KIRO_BIN")"
if [ -z "$ELECTRON_VERSION" ]; then
    log_error "Could not detect Electron version from $KIRO_BIN"
    exit 1
fi
printf '%s\n' "$ELECTRON_VERSION" > "${BUILD_DIR}/.electron-version"

log_ok "Detected Electron version: $ELECTRON_VERSION"
log_ok "App resources at: ${EXTRACT_DIR}/usr/share/kiro/resources/"
log_ok "Stage 20 complete"

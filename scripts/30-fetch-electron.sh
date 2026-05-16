#!/usr/bin/env bash
# 30-fetch-electron.sh - Download the arm64 Electron release matching the
# version detected from the upstream Kiro binary.
#
# Outputs:
#   build/electron-arm64/     extracted Electron arm64 distribution
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

log_step "Stage 30: Fetching Electron ${TARGET_ARCH}"

if [ ! -f "${BUILD_DIR}/.electron-version" ]; then
    log_error "Electron version not detected. Run 20-extract-source.sh first."
    exit 1
fi
ELECTRON_VERSION="$(cat "${BUILD_DIR}/.electron-version")"

DOWNLOAD_DIR="$(build_subdir downloads)"
ZIP="${DOWNLOAD_DIR}/electron-v${ELECTRON_VERSION}-linux-${TARGET_ARCH}.zip"
URL="${ELECTRON_MIRROR}/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-${TARGET_ARCH}.zip"

if [ ! -f "$ZIP" ]; then
    log_info "Downloading $URL"
    wget -q --show-progress -O "$ZIP.tmp" "$URL"
    mv "$ZIP.tmp" "$ZIP"
else
    log_info "Cached: $ZIP"
fi

ELECTRON_DIR="${BUILD_DIR}/electron-${TARGET_ARCH}"
STAMP="${ELECTRON_DIR}/.stamp"
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$ELECTRON_VERSION" ]; then
    log_info "Electron already extracted; skipping"
else
    log_info "Extracting -> $ELECTRON_DIR"
    rm -rf "$ELECTRON_DIR"
    mkdir -p "$ELECTRON_DIR"
    unzip -q "$ZIP" -d "$ELECTRON_DIR"
    printf '%s' "$ELECTRON_VERSION" > "$STAMP"
fi

# Sanity check the binary
if ! file "${ELECTRON_DIR}/electron" | grep -q "ARM aarch64"; then
    log_error "Downloaded electron is not aarch64!"
    file "${ELECTRON_DIR}/electron"
    exit 1
fi

log_ok "Electron ${ELECTRON_VERSION} ${TARGET_ARCH} ready at: ${ELECTRON_DIR}"
log_ok "Stage 30 complete"

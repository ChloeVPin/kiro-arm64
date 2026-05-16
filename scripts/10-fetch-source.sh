#!/usr/bin/env bash
# 10-fetch-source.sh - Locate the upstream Kiro x64 .deb to use as source.
#
# Strategy:
#   1. Honor $KIRO_SOURCE_DEB if exported.
#   2. Otherwise look in build/downloads, ~/Downloads, repo root.
#   3. Print the resolved path and write it to build/.source-deb-path
#
# We do NOT download Kiro automatically because there is no public stable
# download URL we can rely on. Users must provide the .deb themselves.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

log_step "Stage 10: Resolving upstream Kiro x64 source .deb"

DEB="$(find_source_deb)"
if [ -z "$DEB" ]; then
    log_error "No source .deb found."
    log_error ""
    log_error "Download the official x64 Kiro IDE .deb from https://kiro.dev/"
    log_error "and place it in one of:"
    log_error "  - ${BUILD_DIR}/downloads/"
    log_error "  - ~/Downloads/"
    log_error "  - the repo root"
    log_error "Or export KIRO_SOURCE_DEB=/absolute/path/to/kiro-ide-X.Y.Z-stable-linux-x64.deb"
    exit 1
fi

KIRO_VERSION="$(detect_kiro_version "$DEB")"

mkdir -p "${BUILD_DIR}"
printf '%s\n' "$DEB" > "${BUILD_DIR}/.source-deb-path"
printf '%s\n' "$KIRO_VERSION" > "${BUILD_DIR}/.kiro-version"

log_ok "Source .deb: $DEB"
log_ok "Kiro version: $KIRO_VERSION"
log_ok "Stage 10 complete"

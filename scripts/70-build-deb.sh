#!/usr/bin/env bash
# 70-build-deb.sh - Stage and build the final arm64 .deb package.
#
# Inputs:
#   build/kiro-arm64/                  assembled application tree
#   build/icons/                       generated PNG icons
#   assets/kiro-logo.svg               scalable icon
#   packaging/debian/                  control template + maintainer scripts
#   packaging/desktop/kiro.desktop     freedesktop entry
#
# Output:
#   build/dist/kiro-ide-{VERSION}-arm64.deb
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

log_step "Stage 70: Building .deb package"

KIRO_VERSION="$(cat "${BUILD_DIR}/.kiro-version")"
APP_DIR="${BUILD_DIR}/kiro-${TARGET_ARCH}"
ICONS_DIR="${BUILD_DIR}/icons"

if [ ! -d "$APP_DIR" ] || [ ! -d "$ICONS_DIR" ]; then
    log_error "Required inputs missing. Run earlier stages first."
    exit 1
fi

# Stage the deb package tree
PKG="$(build_subdir deb-pkg)"
rm -rf "$PKG"
mkdir -p \
    "$PKG/DEBIAN" \
    "$PKG/usr/share/kiro" \
    "$PKG/usr/share/applications" \
    "$PKG/usr/share/pixmaps" \
    "$PKG/usr/share/bash-completion/completions" \
    "$PKG/usr/bin"

for size in 16 24 32 48 64 128 256 512; do
    mkdir -p "$PKG/usr/share/icons/hicolor/${size}x${size}/apps"
done
mkdir -p "$PKG/usr/share/icons/hicolor/scalable/apps"

# 1. App tree
log_info "Staging application files..."
cp -a "${APP_DIR}/." "$PKG/usr/share/kiro/"

# 2. Icons
log_info "Staging icons..."
for size in 16 24 32 48 64 128 256 512; do
    cp "${ICONS_DIR}/kiro-${size}.png" "$PKG/usr/share/icons/hicolor/${size}x${size}/apps/kiro.png"
done
cp "${REPO_ROOT}/assets/kiro-logo.svg" "$PKG/usr/share/icons/hicolor/scalable/apps/kiro.svg"
cp "${ICONS_DIR}/kiro-512.png" "$PKG/usr/share/pixmaps/kiro.png"

# 3. Desktop entry
cp "${REPO_ROOT}/packaging/desktop/kiro.desktop" "$PKG/usr/share/applications/kiro.desktop"

# 4. /usr/bin symlink (relative)
ln -sf /usr/share/kiro/kiro "$PKG/usr/bin/kiro"

# 5. Bash completion (best-effort)
if [ -f "${APP_DIR}/resources/completions/kiro" ]; then
    cp "${APP_DIR}/resources/completions/kiro" "$PKG/usr/share/bash-completion/completions/kiro"
fi

# 6. DEBIAN control + maintainer scripts (with version substituted)
INSTALLED_KB=$(du -sk "$PKG" | cut -f1)
render_template \
    "${REPO_ROOT}/packaging/debian/control.template" \
    "$PKG/DEBIAN/control" \
    "KIRO_VERSION=${KIRO_VERSION}" \
    "INSTALLED_SIZE=${INSTALLED_KB}"

cp "${REPO_ROOT}/packaging/debian/postinst" "$PKG/DEBIAN/postinst"
cp "${REPO_ROOT}/packaging/debian/postrm" "$PKG/DEBIAN/postrm"
chmod 755 "$PKG/DEBIAN/postinst" "$PKG/DEBIAN/postrm"

# 7. Build the deb (use fakeroot for proper ownership in archive)
DIST="$(build_subdir dist)"
OUT_NAME="${OUTPUT_DEB_NAME//%VERSION%/${KIRO_VERSION}}"
OUT="${DIST}/${OUT_NAME}"

log_info "Building $OUT"
fakeroot dpkg-deb --build "$PKG" "$OUT" 2>&1 | tail -3

log_ok "Built: $OUT ($(du -sh "$OUT" | cut -f1))"
log_ok "Stage 70 complete"
log_info ""
log_info "To install: sudo dpkg -i \"$OUT\""
log_info "To inspect: dpkg-deb --info \"$OUT\""

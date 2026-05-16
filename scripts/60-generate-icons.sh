#!/usr/bin/env bash
# 60-generate-icons.sh - Rasterize PNG icons from assets/kiro-logo.svg
# at all standard freedesktop sizes.
#
# Output:
#   build/icons/kiro-{16,24,32,48,64,128,256,512,1024}.png
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

log_step "Stage 60: Generating PNG icons from SVG"

require_cmd rsvg-convert

SVG="${REPO_ROOT}/assets/kiro-logo.svg"
ICONS_DIR="$(build_subdir icons)"

if [ ! -f "$SVG" ]; then
    log_error "SVG not found: $SVG"
    exit 1
fi

# Skip if the SVG hasn't changed
STAMP="${ICONS_DIR}/.stamp"
SVG_HASH="$(sha1sum "$SVG" | awk '{print $1}')"
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$SVG_HASH" ]; then
    log_info "Icons up-to-date; skipping"
else
    rm -f "${ICONS_DIR}"/*.png
    for size in 16 24 32 48 64 128 256 512 1024; do
        rsvg-convert -w "$size" -h "$size" "$SVG" -o "${ICONS_DIR}/kiro-${size}.png"
    done
    printf '%s' "$SVG_HASH" > "$STAMP"
fi

log_ok "Generated $(ls "${ICONS_DIR}"/*.png | wc -l) PNG icons"
log_ok "Stage 60 complete"

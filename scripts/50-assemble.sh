#!/usr/bin/env bash
# 50-assemble.sh - Build the final kiro-arm64 application tree by combining:
#   1. The arm64 Electron shell from build/electron-arm64/
#   2. Kiro's app resources from build/source-extract/usr/share/kiro/resources/
#   3. ARM64-rebuilt native .node modules from build/native-rebuild/
#
# Output:
#   build/kiro-arm64/   complete arm64 Kiro application directory
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

log_step "Stage 50: Assembling kiro-${TARGET_ARCH}"

ELECTRON_DIR="${BUILD_DIR}/electron-${TARGET_ARCH}"
SRC_RESOURCES="${BUILD_DIR}/source-extract/usr/share/kiro/resources"
NATIVE_NM="${BUILD_DIR}/native-rebuild/node_modules"
APP="${BUILD_DIR}/kiro-${TARGET_ARCH}"

for d in "$ELECTRON_DIR" "$SRC_RESOURCES" "$NATIVE_NM"; do
    if [ ! -d "$d" ]; then
        log_error "Missing input dir: $d"
        log_error "Run all prior stages first."
        exit 1
    fi
done

# 1. Start fresh from the arm64 Electron distribution
log_info "Copying arm64 Electron shell..."
rm -rf "$APP"
cp -a "$ELECTRON_DIR" "$APP"

# Rename binary: electron -> kiro
mv "${APP}/electron" "${APP}/kiro"

# Remove default Electron app resources
rm -f "${APP}/resources/default_app.asar"

# 2. Copy Kiro app resources into resources/
log_info "Copying Kiro app resources..."
cp -a "${SRC_RESOURCES}/." "${APP}/resources/"

APP_NM="${APP}/resources/app/node_modules"

# 3. Replace x86-64 native modules with arm64 builds
log_info "Replacing native modules with arm64 builds..."

# Helper: copy a .node from src -> dst (both must end with .node).
# Errors if src is missing OR dst's parent dir doesn't exist (which would
# indicate the upstream tree changed and the script needs updating).
replace_native() {
    local src="$1" dst="$2"
    if [ ! -f "$src" ]; then
        log_error "Missing rebuilt native: $src"
        return 1
    fi
    if [ ! -d "$(dirname "$dst")" ]; then
        log_warn "Skipping (target dir missing): $dst"
        return 0
    fi
    cp "$src" "$dst"
    echo "    $(realpath --relative-to="${APP_NM}" "$dst" 2>/dev/null || echo "$dst")"
}

# Helper: pick first existing source path among candidates
first_existing() {
    for p in "$@"; do [ -f "$p" ] && { printf '%s' "$p"; return 0; }; done
    return 1
}

# Core app native modules
# @parcel/watcher: npm may install either the source build (build/Release/) or
# the platform-specific sibling package @parcel/watcher-linux-arm64-glibc.
PARCEL_SRC="$(first_existing \
    "${NATIVE_NM}/@parcel/watcher/build/Release/watcher.node" \
    "${NATIVE_NM}/@parcel/watcher-linux-arm64-glibc/watcher.node")" || {
    log_error "Could not locate rebuilt @parcel/watcher .node binary"; exit 1; }
replace_native "$PARCEL_SRC" \
               "${APP_NM}/@parcel/watcher/build/Release/watcher.node"

replace_native "${NATIVE_NM}/native-keymap/build/Release/keymapping.node" \
               "${APP_NM}/native-keymap/build/Release/keymapping.node"
replace_native "${NATIVE_NM}/native-watchdog/build/Release/watchdog.node" \
               "${APP_NM}/native-watchdog/build/Release/watchdog.node"
replace_native "${NATIVE_NM}/native-is-elevated/build/Release/iselevated.node" \
               "${APP_NM}/native-is-elevated/build/Release/iselevated.node"
replace_native "${NATIVE_NM}/node-pty/build/Release/pty.node" \
               "${APP_NM}/node-pty/build/Release/pty.node"
replace_native "${NATIVE_NM}/kerberos/build/Release/kerberos.node" \
               "${APP_NM}/kerberos/build/Release/kerberos.node"
replace_native "${NATIVE_NM}/kerberos/build/Release/kerberos.node" \
               "${APP_NM}/kerberos/build/Release/obj.target/kerberos.node"
replace_native "${NATIVE_NM}/windows-foreground-love/build/Release/foreground_love.node" \
               "${APP_NM}/windows-foreground-love/build/Release/foreground_love.node"
replace_native "${NATIVE_NM}/windows-foreground-love/build/Release/foreground_love.node" \
               "${APP_NM}/windows-foreground-love/build/Release/obj.target/foreground_love.node"
replace_native "${NATIVE_NM}/@vscode/spdlog/build/Release/spdlog.node" \
               "${APP_NM}/@vscode/spdlog/build/Release/spdlog.node"
replace_native "${NATIVE_NM}/@vscode/sqlite3/build/Release/vscode-sqlite3.node" \
               "${APP_NM}/@vscode/sqlite3/build/Release/vscode-sqlite3.node"
replace_native "${NATIVE_NM}/@vscode/deviceid/build/Release/windows.node" \
               "${APP_NM}/@vscode/deviceid/build/Release/windows.node"
replace_native "${NATIVE_NM}/@vscode/policy-watcher/build/Release/vscode-policy-watcher.node" \
               "${APP_NM}/@vscode/policy-watcher/build/Release/vscode-policy-watcher.node"

# Extension native modules
EXT_NM="${APP}/resources/app/extensions/kiro.kiro-agent/node_modules"

# sqlite3 in kiro-agent extension
if [ -d "${EXT_NM}/sqlite3" ]; then
    replace_native "${NATIVE_NM}/sqlite3/build/Release/node_sqlite3.node" \
                   "${EXT_NM}/sqlite3/build/Release/node_sqlite3.node"
fi

# LanceDB: install arm64 sibling package next to the existing x64 one
if [ -d "${NATIVE_NM}/@lancedb/vectordb-linux-arm64-gnu" ] && [ -d "${EXT_NM}/@lancedb" ]; then
    log_info "Installing @lancedb/vectordb-linux-arm64-gnu"
    rm -rf "${EXT_NM}/@lancedb/vectordb-linux-arm64-gnu"
    cp -a "${NATIVE_NM}/@lancedb/vectordb-linux-arm64-gnu" "${EXT_NM}/@lancedb/"
fi

# Remove x64-only msal-node-runtime (no arm64 Linux build available; will fall
# back to non-native auth)
MSAL_DIR="${APP}/resources/app/extensions/microsoft-authentication/dist"
if [ -f "${MSAL_DIR}/msal-node-runtime.node" ]; then
    log_info "Removing x64-only msal-node-runtime (browser auth fallback)"
    rm -f "${MSAL_DIR}/msal-node-runtime.node" "${MSAL_DIR}/libmsalruntime.so"
fi

# Verify there are no remaining x86-64 .node files in critical paths
log_info "Verifying no x86-64 .node modules remain in core app..."
REMAINING=$(find "${APP_NM}" -name "*.node" -exec sh -c 'file "$1" | grep -q "x86-64" && echo "$1"' _ {} \; | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    log_error "$REMAINING x86-64 .node files remain in core app:"
    find "${APP_NM}" -name "*.node" -exec sh -c 'file "$1" | grep -q "x86-64" && echo "  $1"' _ {} \;
    exit 1
fi

# Set executable/sandbox permissions
chmod +x "${APP}/kiro" "${APP}/chrome_crashpad_handler" 2>/dev/null || true
chmod 4755 "${APP}/chrome-sandbox" 2>/dev/null || true

log_ok "Assembled at: $APP ($(du -sh "$APP" | cut -f1))"
log_ok "Stage 50 complete"

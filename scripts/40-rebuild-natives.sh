#!/usr/bin/env bash
# 40-rebuild-natives.sh - Compile/install all required native Node modules
# for the target architecture against the Electron ABI used by Kiro.
#
# Inputs:
#   src/native-rebuild/package.json  declares pinned versions of the modules
#   build/.electron-version          target Electron version
#
# Outputs:
#   build/native-rebuild/node_modules/  contains ARM aarch64 .node binaries
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

log_step "Stage 40: Rebuilding native modules for ${TARGET_ARCH}"

if [ ! -f "${BUILD_DIR}/.electron-version" ]; then
    log_error "Electron version not detected. Run 20-extract-source.sh first."
    exit 1
fi
ELECTRON_VERSION="$(cat "${BUILD_DIR}/.electron-version")"

WORKSPACE="$(build_subdir native-rebuild)"
cp "${REPO_ROOT}/src/native-rebuild/package.json" "${WORKSPACE}/package.json"

cd "$WORKSPACE"

# Skip if already built and lockfile matches
STAMP="${WORKSPACE}/.stamp"
WANT_STAMP="${ELECTRON_VERSION}-${TARGET_ARCH}-$(sha1sum package.json | awk '{print $1}')"
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$WANT_STAMP" ]; then
    log_info "Native modules already built (stamp matches); skipping"
else
    log_info "Installing & building native modules from source..."
    rm -rf node_modules package-lock.json

    # Install a recent node-gyp (>=10) locally; npm's bundled v8.x can't
    # parse modern Electron's config.gypi.
    log_info "Installing local node-gyp >=10..."
    npm install --no-save node-gyp@latest 2>&1 | tail -3
    LOCAL_GYP="$(pwd)/node_modules/.bin/node-gyp"
    if [ ! -x "$LOCAL_GYP" ]; then
        log_error "Failed to install local node-gyp"
        exit 1
    fi

    # Point npm at the new gyp so prebuild-install / install scripts use it
    export npm_config_node_gyp="${LOCAL_GYP}"

    npm install --build-from-source \
        --runtime=electron \
        --target="${ELECTRON_VERSION}" \
        --dist-url=https://electronjs.org/headers \
        --arch="${TARGET_ARCH}" \
        2>&1 | tail -20
    printf '%s' "$WANT_STAMP" > "$STAMP"
fi

# Quick sanity check: only verify the build/Release/*.node modules we will
# actually copy into the assembled app. Some packages ship prebuilds/ trees
# for other platforms (darwin, win32) that we don't care about.
log_info "Verifying built .node binaries are aarch64..."
COUNT=0
WRONG=0
while IFS= read -r f; do
    COUNT=$((COUNT+1))
    if ! file "$f" | grep -q "ARM aarch64"; then
        log_error "Not aarch64: $f"
        WRONG=$((WRONG+1))
    fi
done < <(find "${WORKSPACE}/node_modules" -path "*/build/Release/*.node" -not -path "*/obj.target/*")

if [ "$WRONG" -gt 0 ]; then
    log_error "$WRONG of $COUNT native binaries are not aarch64"
    exit 1
fi
log_ok "All $COUNT native binaries are aarch64"
log_ok "Stage 40 complete"

#!/usr/bin/env bash
# clean.sh - Remove build artifacts.
#
# Usage:
#   ./scripts/clean.sh            remove build/ entirely
#   ./scripts/clean.sh --soft     keep downloads/ (electron zip, source deb)
#   ./scripts/clean.sh --dist     keep only build/dist/ and downloads/
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

MODE="${1:-all}"

case "$MODE" in
    all|"")
        log_step "Removing entire build/ directory"
        rm -rf "${BUILD_DIR}"
        ;;
    --soft)
        log_step "Cleaning build/ (preserving downloads/)"
        find "${BUILD_DIR}" -mindepth 1 -maxdepth 1 ! -name downloads -exec rm -rf {} +
        ;;
    --dist)
        log_step "Cleaning build/ (preserving downloads/ and dist/)"
        find "${BUILD_DIR}" -mindepth 1 -maxdepth 1 ! -name downloads ! -name dist -exec rm -rf {} +
        ;;
    *)
        log_error "Unknown mode: $MODE"
        log_error "Usage: $0 [all|--soft|--dist]"
        exit 1
        ;;
esac

log_ok "Clean complete"

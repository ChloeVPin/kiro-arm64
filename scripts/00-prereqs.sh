#!/usr/bin/env bash
# 00-prereqs.sh - Install build dependencies on Debian/Ubuntu arm64.
#
# Idempotent: safe to run multiple times. Will skip packages already installed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

log_step "Stage 00: Installing build prerequisites"

# System packages required for building native node modules and the deb.
APT_PACKAGES=(
    # Compilation toolchain
    build-essential
    pkg-config
    python3-dev

    # Native module build deps
    libx11-dev
    libxkbfile-dev
    libsecret-1-dev
    libkrb5-dev

    # Icon rasterization
    librsvg2-bin

    # Packaging
    dpkg-dev
    fakeroot

    # Misc
    wget
    unzip
    file
)

# Detect missing packages
MISSING=()
for pkg in "${APT_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
    log_ok "All apt packages already installed"
else
    log_info "Installing: ${MISSING[*]}"
    sudo apt-get update
    sudo apt-get install -y "${MISSING[@]}"
fi

# Verify Node.js >= 20
if ! command -v node >/dev/null 2>&1; then
    log_error "Node.js not found. Install Node.js 20+ (e.g. via nvm or nodesource)."
    log_error "See: https://nodejs.org/"
    exit 1
fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 20 ]; then
    log_error "Node.js $NODE_MAJOR detected; need >= 20"
    exit 1
fi
log_ok "Node.js $(node --version) found"

log_ok "Stage 00 complete"

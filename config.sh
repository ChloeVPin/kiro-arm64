# shellcheck shell=bash
# config.sh - Tunable build configuration
# Override any of these by exporting in your environment before running scripts.

# Repo root (auto-detected)
: "${REPO_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Where all build artifacts go (gitignored)
: "${BUILD_DIR:=${REPO_ROOT}/build}"

# Where to look for the upstream x64 .deb. If empty, scripts will search common
# locations (~/Downloads, ./build/downloads). If set, must be an absolute path
# to a kiro-ide-*-stable-linux-x64.deb file.
: "${KIRO_SOURCE_DEB:=}"

# Target architecture (only arm64 supported today)
: "${TARGET_ARCH:=arm64}"

# Electron download mirror
: "${ELECTRON_MIRROR:=https://github.com/electron/electron/releases/download}"

# Output deb filename pattern - %VERSION% is replaced with the detected Kiro version
: "${OUTPUT_DEB_NAME:=kiro-ide-%VERSION%-arm64.deb}"

# Maintainer info baked into the deb
: "${DEB_MAINTAINER:=Kiro ARM64 Community Build <noreply@github.com>}"

export REPO_ROOT BUILD_DIR KIRO_SOURCE_DEB TARGET_ARCH ELECTRON_MIRROR OUTPUT_DEB_NAME DEB_MAINTAINER

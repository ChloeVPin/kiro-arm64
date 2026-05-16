# shellcheck shell=bash
# scripts/lib/common.sh - Shared bash helpers for all build stages

# Resolve repo root relative to this file
COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${COMMON_LIB_DIR}/../.." && pwd)"
export REPO_ROOT

# Source config
# shellcheck disable=SC1091
source "${REPO_ROOT}/config.sh"

# --- Logging --------------------------------------------------------------

_color() {
    if [ -t 1 ]; then
        printf "\033[%sm%s\033[0m" "$1" "$2"
    else
        printf "%s" "$2"
    fi
}

log_info()  { _color "1;34" "[INFO]"  >&2; printf " %s\n" "$*" >&2; }
log_warn()  { _color "1;33" "[WARN]"  >&2; printf " %s\n" "$*" >&2; }
log_error() { _color "1;31" "[ERROR]" >&2; printf " %s\n" "$*" >&2; }
log_ok()    { _color "1;32" "[OK]"    >&2; printf " %s\n" "$*" >&2; }
log_step()  { _color "1;36" "==>"     >&2; printf " %s\n" "$*" >&2; }

# Fail fast on errors
strict_mode() {
    set -euo pipefail
}

# --- Paths ----------------------------------------------------------------

build_subdir() {
    local sub="$1"
    local dir="${BUILD_DIR}/${sub}"
    mkdir -p "$dir"
    printf "%s" "$dir"
}

# --- Version detection ---------------------------------------------------

# Locate the upstream x64 .deb. Honors $KIRO_SOURCE_DEB if set.
find_source_deb() {
    if [ -n "${KIRO_SOURCE_DEB:-}" ]; then
        if [ -f "$KIRO_SOURCE_DEB" ]; then
            printf "%s" "$KIRO_SOURCE_DEB"
            return 0
        fi
        log_error "KIRO_SOURCE_DEB set but file not found: $KIRO_SOURCE_DEB"
        return 1
    fi

    local search_paths=(
        "${BUILD_DIR}/downloads"
        "${HOME}/Downloads"
        "${REPO_ROOT}"
    )
    local found
    for d in "${search_paths[@]}"; do
        [ -d "$d" ] || continue
        found="$(ls -1 "$d"/kiro-ide-*-stable-linux-x64.deb 2>/dev/null | sort -V | tail -1)"
        if [ -n "$found" ]; then
            printf "%s" "$found"
            return 0
        fi
    done

    log_error "Could not find kiro-ide-*-stable-linux-x64.deb"
    log_error "Place one in ~/Downloads or set KIRO_SOURCE_DEB"
    return 1
}

# Extract Kiro version from the source .deb (e.g. "0.12.184")
detect_kiro_version() {
    local deb="$1"
    dpkg-deb --field "$deb" Version | sed 's/-.*//'
}

# Extract the Electron version embedded in the Kiro main binary.
# Requires the source deb to have been extracted to $1/usr/share/kiro/kiro
detect_electron_version() {
    local kiro_bin="$1"
    strings "$kiro_bin" | grep -oP "Electron/\K[0-9]+\.[0-9]+\.[0-9]+" | head -1
}

# --- Misc utilities ------------------------------------------------------

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found: $cmd"
        log_error "Run scripts/00-prereqs.sh to install build dependencies"
        return 1
    fi
}

# Apply substitutions to a template file.
# Usage: render_template <input> <output> KEY1=val1 KEY2=val2 ...
# Replaces @KEY@ tokens in the template with the corresponding values.
render_template() {
    local input="$1" output="$2"
    shift 2
    local sed_args=()
    while [ $# -gt 0 ]; do
        local pair="$1"
        local key="${pair%%=*}"
        local val="${pair#*=}"
        # Escape sed special chars in val
        local escaped_val
        escaped_val=$(printf '%s' "$val" | sed -e 's/[\/&|]/\\&/g')
        sed_args+=("-e" "s|@${key}@|${escaped_val}|g")
        shift
    done
    sed "${sed_args[@]}" "$input" > "$output"
}

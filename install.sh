#!/usr/bin/env bash
# install.sh - TUI installer for Kiro IDE ARM64
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ChloeVPin/kiro-arm64/main/install.sh | bash
#   ./install.sh                    interactive install
#   ./install.sh --uninstall        remove Kiro
#   ./install.sh --help             show usage
#
# Requirements: bash 4+, wget or curl, dpkg, sudo
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

REPO_OWNER="ChloeVPin"
REPO_NAME="kiro-arm64"
GITHUB_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
INSTALL_DIR="/usr/share/kiro"
BIN_LINK="/usr/bin/kiro"
TMP_DIR=""

# ─── Terminal capabilities ────────────────────────────────────────────────────

TERM_COLS=$(tput cols 2>/dev/null || echo 80)
HAS_COLOR=false
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
    HAS_COLOR=true
fi

# Colors
if $HAS_COLOR; then
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_DIM="\033[2m"
    C_PURPLE="\033[38;5;129m"
    C_GREEN="\033[38;5;114m"
    C_RED="\033[38;5;203m"
    C_YELLOW="\033[38;5;221m"
    C_CYAN="\033[38;5;117m"
    C_WHITE="\033[97m"
    C_GRAY="\033[38;5;245m"
    C_UP="\033[1A"
    C_CLEAR="\033[2K"
else
    C_RESET="" C_BOLD="" C_DIM="" C_PURPLE="" C_GREEN="" C_RED=""
    C_YELLOW="" C_CYAN="" C_WHITE="" C_GRAY="" C_UP="" C_CLEAR=""
fi

# ─── TUI primitives ──────────────────────────────────────────────────────────

# Cursor control
cursor_hide()   { $HAS_COLOR && printf "\033[?25l"; }
cursor_show()   { $HAS_COLOR && printf "\033[?25h"; }
cursor_up()     { printf "${C_UP}"; }
line_clear()    { printf "\r${C_CLEAR}"; }

# Print on current line (overwrites)
print_line() {
    line_clear
    printf "%b" "$1"
}

# Print and advance to next line
println() {
    printf "%b\n" "$1"
}

# Spinner frames
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_PID=""

spinner_start() {
    local msg="$1"
    SPINNER_MSG="$msg"
    if ! $HAS_COLOR; then
        printf "  ... %s" "$msg" >&2
        return
    fi
    cursor_hide
    (
        trap 'exit 0' TERM
        local i=0
        while true; do
            local frame="${SPINNER_FRAMES[$((i % ${#SPINNER_FRAMES[@]}))]}"
            print_line "  ${C_PURPLE}${frame}${C_RESET} ${C_WHITE}${msg}${C_RESET}"
            sleep 0.08
            i=$((i + 1))
        done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID" 2>/dev/null
}

spinner_stop() {
    local status="$1" msg="$2"
    if ! $HAS_COLOR; then
        if [ "$status" = "ok" ]; then
            printf "\r  [OK] %s\n" "$msg" >&2
        elif [ "$status" = "skip" ]; then
            printf "\r  [--] %s\n" "$msg" >&2
        else
            printf "\r  [!!] %s\n" "$msg" >&2
        fi
        SPINNER_PID=""
        return
    fi
    if [ -n "$SPINNER_PID" ]; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
    fi
    line_clear
    if [ "$status" = "ok" ]; then
        println "  ${C_GREEN}✓${C_RESET} ${C_WHITE}${msg}${C_RESET}"
    elif [ "$status" = "skip" ]; then
        println "  ${C_GRAY}○${C_RESET} ${C_GRAY}${msg}${C_RESET}"
    else
        println "  ${C_RED}✗${C_RESET} ${C_WHITE}${msg}${C_RESET}"
    fi
    cursor_show
}

# Progress bar (called repeatedly to update in place)
progress_bar() {
    local current="$1" total="$2" label="$3"
    local pct=$((current * 100 / total))
    local bar_width=$((TERM_COLS - 30))
    [ "$bar_width" -gt 50 ] && bar_width=50
    [ "$bar_width" -lt 20 ] && bar_width=20
    local filled=$((pct * bar_width / 100))
    local empty=$((bar_width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    print_line "  ${C_PURPLE}${bar}${C_RESET} ${C_DIM}${pct}%%${C_RESET} ${C_GRAY}${label}${C_RESET}"
}

# ─── Utility functions ────────────────────────────────────────────────────────

cleanup() {
    cursor_show
    [ -n "$SPINNER_PID" ] && kill "$SPINNER_PID" 2>/dev/null || true
    [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

die() {
    spinner_stop "fail" "$1"
    println ""
    println "  ${C_RED}Installation failed.${C_RESET}"
    println "  ${C_GRAY}If this persists, open an issue at:${C_RESET}"
    println "  ${C_CYAN}https://github.com/${REPO_OWNER}/${REPO_NAME}/issues${C_RESET}"
    println ""
    exit 1
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        die "Required command not found: $1"
    fi
}

# Download with progress (uses wget or curl)
download() {
    local url="$1" dest="$2" label="$3"
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "$dest" "$url" 2>&1 | \
            while IFS= read -r line; do
                local pct
                pct=$(echo "$line" | grep -oP '\d+(?=%)' | tail -1)
                if [ -n "$pct" ]; then
                    progress_bar "$pct" 100 "$label"
                fi
            done
    elif command -v curl >/dev/null 2>&1; then
        curl -fSL --progress-bar -o "$dest" "$url" 2>&1 | \
            while IFS= read -r line; do
                local pct
                pct=$(echo "$line" | grep -oP '\d+\.\d' | head -1 | cut -d. -f1)
                if [ -n "$pct" ]; then
                    progress_bar "$pct" 100 "$label"
                fi
            done
    else
        die "Neither wget nor curl found"
    fi
}

# ─── Header ──────────────────────────────────────────────────────────────────

print_header() {
    println ""
    println "  ${C_PURPLE}${C_BOLD} /\$\$   /\$\$ /\$\$\$\$\$\$ /\$\$\$\$\$\$\$   /\$\$\$\$\$\$${C_RESET}"
    println "  ${C_PURPLE}${C_BOLD}| \$\$  /\$\$/|_  \$\$_/| \$\$__  \$\$ /\$\$__  \$\$${C_RESET}"
    println "  ${C_PURPLE}${C_BOLD}| \$\$ /\$\$/   | \$\$  | \$\$  \\ \$\$| \$\$  \\ \$\$${C_RESET}"
    println "  ${C_PURPLE}${C_BOLD}| \$\$\$\$\$/    | \$\$  | \$\$\$\$\$\$\$/| \$\$  | \$\$${C_RESET}"
    println "  ${C_PURPLE}${C_BOLD}| \$\$  \$\$    | \$\$  | \$\$__  \$\$| \$\$  | \$\$${C_RESET}"
    println "  ${C_PURPLE}${C_BOLD}| \$\$\\\  \$\$   | \$\$  | \$\$  \\ \$\$| \$\$  | \$\$${C_RESET}"
    println "  ${C_PURPLE}${C_BOLD}| \$\$ \\\  \$\$ /\$\$\$\$\$\$| \$\$  | \$\$|  \$\$\$\$\$\$/${C_RESET}"
    println "  ${C_PURPLE}${C_BOLD}|__/  \\__/|______/|__/  |__/ \\______/${C_RESET}"
    println ""
    println "  ${C_WHITE}${C_BOLD}Kiro IDE for ARM64 Linux${C_RESET}"
    println "  ${C_GRAY}Community build installer${C_RESET}"
    println ""
}

# ─── Preflight checks ────────────────────────────────────────────────────────

preflight() {
    spinner_start "Checking system requirements"
    sleep 0.3

    # Architecture
    local arch
    arch="$(uname -m)"
    if [ "$arch" != "aarch64" ] && [ "$arch" != "arm64" ]; then
        spinner_stop "fail" "Checking system requirements"
        die "This installer is for ARM64 systems. Detected: $arch"
    fi

    # OS family
    if [ ! -f /etc/debian_version ] && ! command -v dpkg >/dev/null 2>&1; then
        spinner_stop "fail" "Checking system requirements"
        die "This installer requires a Debian-based system (Debian, Ubuntu, etc.)"
    fi

    # Required commands
    for cmd in dpkg sudo; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            spinner_stop "fail" "Checking system requirements"
            die "Required command not found: $cmd"
        fi
    done

    spinner_stop "ok" "System: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"') ($arch)"
}

# ─── Version detection ────────────────────────────────────────────────────────

detect_installed_version() {
    if dpkg -s kiro >/dev/null 2>&1; then
        dpkg -s kiro | grep "^Version:" | awk '{print $2}' | sed 's/-.*//'
    else
        echo ""
    fi
}

fetch_latest_release() {
    local json=""
    if command -v curl >/dev/null 2>&1; then
        json=$(curl -fsSL "$GITHUB_API" 2>/dev/null || echo "")
    elif command -v wget >/dev/null 2>&1; then
        json=$(wget -qO- "$GITHUB_API" 2>/dev/null || echo "")
    fi

    if [ -z "$json" ]; then
        return 1
    fi

    # Parse tag_name and browser_download_url for the .deb asset
    LATEST_TAG=$(echo "$json" | grep -oP '"tag_name"\s*:\s*"\K[^"]+' | head -1)
    LATEST_URL=$(echo "$json" | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+\.deb' | head -1)
    LATEST_VERSION="${LATEST_TAG#v}"

    if [ -z "$LATEST_TAG" ] || [ -z "$LATEST_URL" ]; then
        return 1
    fi
    return 0
}

# ─── Install flow ─────────────────────────────────────────────────────────────

do_install() {
    print_header

    # Preflight
    preflight

    # Check installed version
    local installed
    installed="$(detect_installed_version)"
    if [ -n "$installed" ]; then
        println "  ${C_GRAY}Installed version: ${C_WHITE}${installed}${C_RESET}"
    fi

    # Fetch latest release info
    spinner_start "Fetching latest release info"
    if ! fetch_latest_release; then
        spinner_stop "fail" "Fetching latest release info"
        die "Could not reach GitHub releases. Check your network connection."
    fi
    spinner_stop "ok" "Latest release: ${C_BOLD}${LATEST_VERSION}${C_RESET}"

    # Compare versions
    if [ "$installed" = "$LATEST_VERSION" ]; then
        println ""
        println "  ${C_GREEN}${C_BOLD}Already up to date.${C_RESET}"
        println ""
        exit 0
    fi

    if [ -n "$installed" ]; then
        println "  ${C_CYAN}Upgrading: ${installed} -> ${LATEST_VERSION}${C_RESET}"
    fi
    println ""

    # Download
    TMP_DIR="$(mktemp -d)"
    local deb_path="${TMP_DIR}/kiro-arm64.deb"

    println "  ${C_WHITE}Downloading...${C_RESET}"
    download "$LATEST_URL" "$deb_path" "kiro-ide-${LATEST_VERSION}-arm64.deb"
    println ""
    println "  ${C_GREEN}✓${C_RESET} ${C_WHITE}Download complete${C_RESET}"
    println ""

    # Verify the downloaded file
    spinner_start "Verifying package"
    sleep 0.2
    if ! dpkg-deb --info "$deb_path" >/dev/null 2>&1; then
        spinner_stop "fail" "Verifying package"
        die "Downloaded file is not a valid .deb package"
    fi
    local pkg_arch
    pkg_arch=$(dpkg-deb --field "$deb_path" Architecture)
    if [ "$pkg_arch" != "arm64" ]; then
        spinner_stop "fail" "Verifying package"
        die "Package architecture mismatch: expected arm64, got $pkg_arch"
    fi
    spinner_stop "ok" "Package verified (arm64, $(du -h "$deb_path" | cut -f1))"

    # Install
    spinner_start "Installing Kiro IDE"
    local install_output
    if ! install_output=$(sudo dpkg -i "$deb_path" 2>&1); then
        spinner_stop "fail" "Installing Kiro IDE"
        # Try to fix dependencies
        spinner_start "Resolving dependencies"
        if sudo apt-get install -f -y >/dev/null 2>&1; then
            spinner_stop "ok" "Dependencies resolved"
            spinner_start "Retrying installation"
            if ! sudo dpkg -i "$deb_path" >/dev/null 2>&1; then
                spinner_stop "fail" "Retrying installation"
                die "Installation failed. Run manually: sudo dpkg -i $deb_path"
            fi
            spinner_stop "ok" "Kiro IDE installed"
        else
            spinner_stop "fail" "Resolving dependencies"
            die "Could not resolve dependencies. Run: sudo apt-get install -f"
        fi
    else
        spinner_stop "ok" "Kiro IDE installed"
    fi

    # Verify installation
    spinner_start "Verifying installation"
    sleep 0.2
    if [ -x "$INSTALL_DIR/kiro" ] && [ -L "$BIN_LINK" ]; then
        spinner_stop "ok" "Binary at ${BIN_LINK}"
    else
        spinner_stop "skip" "Binary link not found (may need PATH update)"
    fi

    # Check desktop integration
    if [ -f /usr/share/applications/kiro.desktop ]; then
        spinner_stop "ok" "Desktop entry registered" 2>/dev/null || \
        println "  ${C_GREEN}✓${C_RESET} ${C_WHITE}Desktop entry registered${C_RESET}"
    fi

    # Done
    println ""
    println "  ${C_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    println ""
    println "  ${C_GREEN}${C_BOLD}Installation complete.${C_RESET}"
    println ""
    println "  ${C_WHITE}Launch Kiro from your application menu or run:${C_RESET}"
    println "  ${C_CYAN}kiro${C_RESET}"
    println ""
}

# ─── Uninstall flow ───────────────────────────────────────────────────────────

do_uninstall() {
    print_header

    local installed
    installed="$(detect_installed_version)"
    if [ -z "$installed" ]; then
        println "  ${C_GRAY}Kiro IDE is not installed.${C_RESET}"
        println ""
        exit 0
    fi

    println "  ${C_WHITE}Removing Kiro IDE ${installed}...${C_RESET}"
    println ""

    spinner_start "Removing package"
    if sudo dpkg -r kiro >/dev/null 2>&1; then
        spinner_stop "ok" "Package removed"
    else
        spinner_stop "fail" "Package removal failed"
        die "Could not remove package. Try: sudo dpkg -r kiro"
    fi

    spinner_start "Cleaning up"
    sleep 0.3
    # Remove leftover config dirs
    rm -rf "${HOME}/.config/Kiro" 2>/dev/null || true
    spinner_stop "ok" "User data preserved at ~/.config/Kiro (remove manually if desired)"

    println ""
    println "  ${C_GREEN}${C_BOLD}Uninstall complete.${C_RESET}"
    println ""
}

# ─── Local install flow ───────────────────────────────────────────────────────

do_install_local() {
    print_header
    preflight

    local deb_path="$LOCAL_DEB"
    if [ ! -f "$deb_path" ]; then
        die "File not found: $deb_path"
    fi

    println ""

    # Verify
    spinner_start "Verifying package"
    if ! dpkg-deb --info "$deb_path" >/dev/null 2>&1; then
        spinner_stop "fail" "Verifying package"
        die "Not a valid .deb package: $deb_path"
    fi
    local pkg_arch
    pkg_arch=$(dpkg-deb --field "$deb_path" Architecture)
    if [ "$pkg_arch" != "arm64" ]; then
        spinner_stop "fail" "Verifying package"
        die "Package architecture mismatch: expected arm64, got $pkg_arch"
    fi
    local pkg_ver
    pkg_ver=$(dpkg-deb --field "$deb_path" Version | sed 's/-.*//')
    spinner_stop "ok" "Package verified: Kiro ${pkg_ver} (arm64, $(du -h "$deb_path" | cut -f1))"

    # Install
    spinner_start "Installing Kiro IDE ${pkg_ver}"
    if ! sudo dpkg -i "$deb_path" >/dev/null 2>&1; then
        spinner_stop "fail" "Installing Kiro IDE"
        spinner_start "Resolving dependencies"
        if sudo apt-get install -f -y >/dev/null 2>&1; then
            spinner_stop "ok" "Dependencies resolved"
            spinner_start "Retrying installation"
            if ! sudo dpkg -i "$deb_path" >/dev/null 2>&1; then
                spinner_stop "fail" "Retrying installation"
                die "Installation failed"
            fi
            spinner_stop "ok" "Kiro IDE installed"
        else
            spinner_stop "fail" "Resolving dependencies"
            die "Could not resolve dependencies. Run: sudo apt-get install -f"
        fi
    else
        spinner_stop "ok" "Kiro IDE ${pkg_ver} installed"
    fi

    println ""
    println "  ${C_PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    println ""
    println "  ${C_GREEN}${C_BOLD}Installation complete.${C_RESET}"
    println ""
    println "  ${C_WHITE}Launch Kiro from your application menu or run:${C_RESET}"
    println "  ${C_CYAN}kiro${C_RESET}"
    println ""
}

# ─── Entry point ──────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --uninstall|-u)
            do_uninstall
            ;;
        --local)
            if [ -z "${2:-}" ]; then
                println "Usage: install.sh --local <path-to-deb>"
                exit 1
            fi
            LOCAL_DEB="$2"
            do_install_local
            ;;
        --help|-h)
            println "Usage: install.sh [OPTIONS]"
            println ""
            println "Options:"
            println "  (none)            Install or update from GitHub releases"
            println "  --local <file>    Install from a local .deb file"
            println "  --uninstall       Remove Kiro IDE"
            println "  --help            Show this help"
            println ""
            exit 0
            ;;
        "")
            do_install
            ;;
        *)
            println "Unknown option: $1"
            println "Run with --help for usage."
            exit 1
            ;;
    esac
}

main "$@"

#!/usr/bin/env bash
# build-all.sh - Run all build stages in order.
#
# Usage:
#   ./scripts/build-all.sh           run all stages
#   ./scripts/build-all.sh --from 30 start from stage 30
#   ./scripts/build-all.sh --to 50   stop after stage 50
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

FROM=0
TO=99

while [ $# -gt 0 ]; do
    case "$1" in
        --from) FROM="$2"; shift 2 ;;
        --to)   TO="$2"; shift 2 ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) log_error "Unknown arg: $1"; exit 1 ;;
    esac
done

STAGES=(
    "00:00-prereqs.sh"
    "10:10-fetch-source.sh"
    "20:20-extract-source.sh"
    "30:30-fetch-electron.sh"
    "40:40-rebuild-natives.sh"
    "50:50-assemble.sh"
    "60:60-generate-icons.sh"
    "70:70-build-deb.sh"
)

START=$(date +%s)
for entry in "${STAGES[@]}"; do
    num="${entry%%:*}"
    script="${entry##*:}"
    if [ "$num" -lt "$FROM" ] || [ "$num" -gt "$TO" ]; then
        log_info "Skipping stage $num (outside --from/--to range)"
        continue
    fi
    bash "${SCRIPT_DIR}/${script}"
done
END=$(date +%s)

log_ok "All stages complete in $((END - START))s"
log_info "Final .deb is in ${BUILD_DIR}/dist/"

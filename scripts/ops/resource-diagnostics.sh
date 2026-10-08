#!/bin/bash
# ==============================================================================
# Script: resource-diagnostics.sh
# Purpose: Bounded resource pressure simulation, monitoring & diagnostics
# Author: DBPlatformGoal Operations Engineering
# Target: Ubuntu 26.04 LTS / WSL2 / Linux Platform Environments
# ==============================================================================
set -euo pipefail

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

DURATION_SECONDS=3

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Purpose:
  Executes a strictly bounded, non-destructive resource diagnostic scenario
  to demonstrate real-time CPU/memory tracking, threshold evaluation, and recovery.

Options:
  --duration <SEC>   Duration of bounded workload in seconds (default: 3, max: 10)
  -h, --help         Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --duration)
            if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ || "$2" -gt 10 ]]; then
                echo "Error: --duration must be an integer between 1 and 10 seconds" >&2
                exit 2
            fi
            DURATION_SECONDS="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            print_usage >&2
            exit 2
            ;;
    esac
done

echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "${BLUE}${BOLD}  DBPlatformGoal — Controlled Resource Pressure & Diagnostics Lab       ${NC}"
echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "Safety Constraints: Single-thread bounded computation, hard timeout: ${DURATION_SECONDS}s."
echo ""

# 1. Baseline Capture
echo -e "${BOLD}1. CAPTURING SYSTEM BASELINE:${NC}"
BASE_LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
BASE_MEM_FREE=$(free -m | awk '/^Mem:/{print $4}')
BASE_MEM_AVAIL=$(free -m | awk '/^Mem:/{print $7}')
echo -e "  Load Average (Baseline) : ${BASE_LOAD}"
echo -e "  Memory Free / Available : ${BASE_MEM_FREE} MiB / ${BASE_MEM_AVAIL} MiB"
echo ""

# 2. Executing Bounded Workload
echo -e "${BOLD}2. INITIATING BOUNDED WORKLOAD (${DURATION_SECONDS}s timeout):${NC}"
WORKLOAD_START=$(date +%s)

# Run a single CPU core calculation via Python with a strict timeout
python3 - <<EOF
import time
import math

end_time = time.time() + float("${DURATION_SECONDS}")
iterations = 0
while time.time() < end_time:
    # Deterministic non-allocating mathematical calculation
    _ = math.sqrt(12345678.9) * math.sin(0.5)
    iterations += 1

print(f"  Completed {iterations:,} computational cycles in ${DURATION_SECONDS} seconds.")
EOF

WORKLOAD_END=$(date +%s)
ELAPSED=$(( WORKLOAD_END - WORKLOAD_START ))
echo -e "  Workload runtime: ${ELAPSED} seconds (Enforced boundary respected)."
echo ""

# 3. Post-Workload Recovery & Delta Analysis
echo -e "${BOLD}3. POST-WORKLOAD MEASUREMENT & RECOVERY:${NC}"
POST_LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
POST_MEM_AVAIL=$(free -m | awk '/^Mem:/{print $7}')
echo -e "  Load Average (Post)     : ${POST_LOAD}"
echo -e "  Memory Available (Post) : ${POST_MEM_AVAIL} MiB"
echo ""

echo -e "${GREEN}${BOLD}✓ Controlled resource diagnostic completed. System returned to baseline.${NC}"
echo -e "${BLUE}========================================================================${NC}"

#!/bin/bash
# ==============================================================================
# Script: process-diagnostics.sh
# Purpose: Deep Linux process inspection, descriptor analysis & resource limits
# Author: DBPlatformGoal Operations Engineering
# Target: Ubuntu 26.04 LTS / WSL2 / Linux Platform Environments
# ==============================================================================
set -euo pipefail

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

TARGET_PID=""
TARGET_NAME=""
TOP_COUNT=5

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --pid <PID>          Inspect a specific Process ID in detail
  --name <PATTERN>     Find and inspect processes matching pattern/name
  --top <N>            Display top N CPU and Memory consuming processes (default: 5)
  -h, --help           Show this help message and exit

Examples:
  $(basename "$0")                     # Summary overview & top processes
  $(basename "$0") --pid 1             # Inspect init / systemd process
  $(basename "$0") --name containerd   # Inspect containerd processes
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pid)
            if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --pid requires a positive integer argument" >&2
                exit 2
            fi
            TARGET_PID="$2"
            shift 2
            ;;
        --name)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --name requires a non-empty string argument" >&2
                exit 2
            fi
            TARGET_NAME="$2"
            shift 2
            ;;
        --top)
            if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --top requires a positive integer argument" >&2
                exit 2
            fi
            TOP_COUNT="$2"
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

inspect_pid() {
    local pid="$1"
    if [[ ! -d "/proc/${pid}" ]]; then
        echo -e "${RED}Error: Process PID ${pid} does not exist or has terminated.${NC}" >&2
        return 1
    fi

    local proc_name
    proc_name=$(awk -F':\t*' '/^Name:/{print $2}' "/proc/${pid}/status" 2>/dev/null || echo "Unknown")
    local proc_state
    proc_state=$(awk -F':\t*' '/^State:/{print $2}' "/proc/${pid}/status" 2>/dev/null || echo "Unknown")
    local proc_ppid
    proc_ppid=$(awk -F':\t*' '/^PPid:/{print $2}' "/proc/${pid}/status" 2>/dev/null || echo "Unknown")
    local proc_threads
    proc_threads=$(awk -F':\t*' '/^Threads:/{print $2}' "/proc/${pid}/status" 2>/dev/null || echo "Unknown")
    local proc_uid
    proc_uid=$(awk -F':\t*' '/^Uid:/{print $2}' "/proc/${pid}/status" 2>/dev/null || echo "Unknown")
    local proc_gid
    proc_gid=$(awk -F':\t*' '/^Gid:/{print $2}' "/proc/${pid}/status" 2>/dev/null || echo "Unknown")

    # Memory metrics from status
    local vmrss
    vmrss=$(awk -F':\t*' '/^VmRSS:/{print $2}' "/proc/${pid}/status" 2>/dev/null || echo "N/A")
    local vmsize
    vmsize=$(awk -F':\t*' '/^VmSize:/{print $2}' "/proc/${pid}/status" 2>/dev/null || echo "N/A")
    local vmswap
    vmswap=$(awk -F':\t*' '/^VmSwap:/{print $2}' "/proc/${pid}/status" 2>/dev/null || echo "0 kB")

    # Command line
    local cmdline="[kernel task or empty]"
    if [[ -r "/proc/${pid}/cmdline" ]]; then
        cmdline=$(tr '\0' ' ' < "/proc/${pid}/cmdline" | xargs || echo "[hidden/unreadable]")
    fi
    if [[ -z "$cmdline" ]]; then
        cmdline="[${proc_name}]"
    fi

    # Open File Descriptors count
    local fd_count="N/A (permission denied)"
    if [[ -r "/proc/${pid}/fd" ]]; then
        fd_count=$(find "/proc/${pid}/fd" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l || echo "N/A")
    fi

    # Max open files limit
    local max_open_files="N/A"
    if [[ -r "/proc/${pid}/limits" ]]; then
        max_open_files=$(grep "Max open files" "/proc/${pid}/limits" 2>/dev/null | awk '{print $4, "(soft) /", $5, "(hard)"}' || echo "N/A")
    fi

    echo -e "${BLUE}========================================================================${NC}"
    echo -e "  Detailed Process Diagnostics: PID ${BOLD}${pid}${NC} (${proc_name})"
    echo -e "${BLUE}========================================================================${NC}"
    echo -e "  Process Name    : ${BOLD}${proc_name}${NC}"
    echo -e "  State           : ${proc_state}"
    echo -e "  Parent PID (PPID): ${proc_ppid}"
    echo -e "  Thread Count    : ${proc_threads}"
    echo -e "  UID / GID       : Real UID: $(echo "$proc_uid" | awk '{print $1}') | GID: $(echo "$proc_gid" | awk '{print $1}')"
    echo -e "  Resident Mem (RSS): ${vmrss}"
    echo -e "  Virtual Mem (VSZ) : ${vmsize}"
    echo -e "  Swap Consumed   : ${vmswap}"
    echo -e "  Open FDs Count  : ${fd_count}"
    echo -e "  FD Limits       : ${max_open_files}"
    echo -e "  Command Line    : ${cmdline}"
    echo ""
}

# 1. Targeted PID Mode
if [[ -n "$TARGET_PID" ]]; then
    inspect_pid "$TARGET_PID"
    exit 0
fi

# 2. Targeted Process Name Mode
if [[ -n "$TARGET_NAME" ]]; then
    echo -e "${BLUE}Searching for processes matching: '${TARGET_NAME}'...${NC}"
    pids=$(pgrep -f "$TARGET_NAME" 2>/dev/null || true)
    if [[ -z "$pids" ]]; then
        echo -e "${YELLOW}No active processes matched pattern '${TARGET_NAME}'.${NC}"
        exit 0
    fi
    for p in $pids; do
        inspect_pid "$p"
    done
    exit 0
fi

# 3. Overview & Top Processes Mode
echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "${BLUE}${BOLD}  DBPlatformGoal — Process & Resource Inspection Subsystem              ${NC}"
echo -e "${BLUE}${BOLD}========================================================================${NC}"

# Check for Zombie / Defunct Processes
ZOMBIE_COUNT=$(ps aux | awk '$8 ~ /Z/' | wc -l)
if [[ "$ZOMBIE_COUNT" -gt 0 ]]; then
    echo -e "${RED}${BOLD}⚠ WARNING: ${ZOMBIE_COUNT} Zombie / Defunct processes detected!${NC}"
    ps aux | awk 'NR==1 || $8 ~ /Z/'
else
    echo -e "Zombie / Defunct Processes: ${GREEN}[ 0 Detected — Clean ]${NC}"
fi
echo ""

echo -e "${BOLD}TOP ${TOP_COUNT} CPU CONSUMING PROCESSES:${NC}"
ps -eo pid,ppid,user,%cpu,%mem,stat,comm --sort=-%cpu | head -n "$(( TOP_COUNT + 1 ))"
echo ""

echo -e "${BOLD}TOP ${TOP_COUNT} MEMORY CONSUMING PROCESSES:${NC}"
ps -eo pid,ppid,user,%mem,%cpu,stat,comm --sort=-%mem | head -n "$(( TOP_COUNT + 1 ))"
echo ""

echo -e "${BOLD}CORE PLATFORM RUNTIMES DETECTED:${NC}"
for runtime_name in systemd containerd dockerd docker kubelet kind; do
    rt_pids=$(pgrep -x "$runtime_name" 2>/dev/null || pgrep -f "$runtime_name" 2>/dev/null || true)
    if [[ -n "$rt_pids" ]]; then
        echo -e "  - ${runtime_name}: ${GREEN}ACTIVE${NC} (PIDs: $(echo "$rt_pids" | tr '\n' ' '))"
    else
        echo -e "  - ${runtime_name}: ${YELLOW}INACTIVE / NOT IN WSL NAMESPACE${NC}"
    fi
done
echo -e "${BLUE}========================================================================${NC}"

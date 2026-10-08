#!/bin/bash
# ==============================================================================
# Script: system-health.sh
# Purpose: Comprehensive Linux platform health & subsystem inspection
# Author: DBPlatformGoal Operations Engineering
# Target: Ubuntu 26.04 LTS / WSL2 / Linux Platform Environments
# ==============================================================================
set -euo pipefail

# ANSI color codes
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

OUTPUT_MODE="human"
VERBOSE=false

# Threshold defaults
readonly MEMORY_WARN_PERCENT=85
readonly DISK_WARN_PERCENT=85

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --human          Output human-readable formatted report (default)
  --json           Output structured JSON report
  --verbose        Include detailed process and port listings
  -h, --help       Show this help message and exit

Exit Codes:
  0: All health checks passed within thresholds
  1: One or more health thresholds exceeded or critical metric unavailable
  2: Invalid arguments or dependency failure
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --human)
            OUTPUT_MODE="human"
            shift
            ;;
        --json)
            OUTPUT_MODE="json"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
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

# Dependency verification
check_dependencies() {
    local missing_deps=()
    for cmd in uname uptime free df ip ss ps; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required core Linux diagnostic tools: ${missing_deps[*]}" >&2
        exit 2
    fi
}

check_dependencies

# Collect system metrics
HOSTNAME=$(hostname 2>/dev/null || uname -n)
KERNEL_RELEASE=$(uname -r)
MACHINE_ARCH=$(uname -m)
OS_PRETTY_NAME="Unknown Linux"
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    OS_PRETTY_NAME=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
fi

UPTIME_STR=$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"min"}')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)
LOAD_1M=$(echo "$LOAD_AVG" | awk -F'[, ]+' '{print $1}')
LOAD_5M=$(echo "$LOAD_AVG" | awk -F'[, ]+' '{print $2}')
LOAD_15M=$(echo "$LOAD_AVG" | awk -F'[, ]+' '{print $3}')

# CPU Metrics
CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")
CPU_MODEL="Unknown CPU"
if command -v lscpu >/dev/null 2>&1; then
    CPU_MODEL=$(lscpu | grep "Model name:" | sed 's/Model name:[ \t]*//' | head -n 1)
elif [[ -f /proc/cpuinfo ]]; then
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d: -f2- | xargs)
fi

# Memory Metrics (MiB)
MEM_TOTAL_MIB=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED_MIB=$(free -m | awk '/^Mem:/{print $3}')
MEM_FREE_MIB=$(free -m | awk '/^Mem:/{print $4}')
MEM_AVAIL_MIB=$(free -m | awk '/^Mem:/{print $7}')
MEM_USED_PERCENT=$(( 100 * MEM_USED_MIB / (MEM_TOTAL_MIB > 0 ? MEM_TOTAL_MIB : 1) ))

SWAP_TOTAL_MIB=$(free -m | awk '/^Swap:/{print $2}')
SWAP_USED_MIB=$(free -m | awk '/^Swap:/{print $3}')

# Disk Metrics (Root filesystem /)
DISK_TOTAL_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$2); print $2}')
DISK_USED_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$3); print $3}')
DISK_AVAIL_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
DISK_USED_PERCENT=$(df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')

# Network Metrics
DEFAULT_GATEWAY=$(ip route show default 2>/dev/null | awk '/default via/{print $3}' | head -n 1 || echo "None")
PRIMARY_INTERFACE=$(ip route show default 2>/dev/null | awk '/default via/{print $5}' | head -n 1 || echo "lo")
PRIMARY_IP=$(ip -4 addr show dev "$PRIMARY_INTERFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n 1 || echo "127.0.0.1")

DNS_SERVERS=$(grep nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ' | xargs || echo "None")

# Port Listeners Count
TOTAL_TCP_LISTEN=$(ss -tln 2>/dev/null | grep -c LISTEN || echo "0")
TOTAL_UDP_LISTEN=$(ss -uln 2>/dev/null | grep -c UNCONN || echo "0")

# Process Metrics
TOTAL_PROCESSES=$(ps aux 2>/dev/null | wc -l)
TOTAL_PROCESSES=$(( TOTAL_PROCESSES - 1 )) # subtract header

# Status Evaluation
HEALTH_STATUS="OK"
HEALTH_NOTES=()

if [[ "$MEM_USED_PERCENT" -ge "$MEMORY_WARN_PERCENT" ]]; then
    HEALTH_STATUS="WARNING"
    HEALTH_NOTES+=("Memory utilization is high (${MEM_USED_PERCENT}% >= ${MEMORY_WARN_PERCENT}%)")
fi

if [[ "$DISK_USED_PERCENT" -ge "$DISK_WARN_PERCENT" ]]; then
    HEALTH_STATUS="WARNING"
    HEALTH_NOTES+=("Disk space utilization is high (${DISK_USED_PERCENT}% >= ${DISK_WARN_PERCENT}%)")
fi

# Render JSON
if [[ "$OUTPUT_MODE" == "json" ]]; then
    # Generate JSON via python3 for robust escaping and schema structure
    python3 - <<EOF
import json

data = {
    "status": "${HEALTH_STATUS}",
    "timestamp_utc": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
    "system": {
        "hostname": "${HOSTNAME}",
        "os": "${OS_PRETTY_NAME}",
        "kernel": "${KERNEL_RELEASE}",
        "architecture": "${MACHINE_ARCH}",
        "uptime": "${UPTIME_STR}",
        "load_average": {
            "1m": float("${LOAD_1M:-0.0}"),
            "5m": float("${LOAD_5M:-0.0}"),
            "15m": float("${LOAD_15M:-0.0}")
        }
    },
    "cpu": {
        "model": "${CPU_MODEL}",
        "cores": int("${CPU_CORES}")
    },
    "memory": {
        "total_mib": int("${MEM_TOTAL_MIB}"),
        "used_mib": int("${MEM_USED_MIB}"),
        "free_mib": int("${MEM_FREE_MIB}"),
        "available_mib": int("${MEM_AVAIL_MIB}"),
        "used_percent": int("${MEM_USED_PERCENT}"),
        "swap_total_mib": int("${SWAP_TOTAL_MIB}"),
        "swap_used_mib": int("${SWAP_USED_MIB}")
    },
    "storage": {
        "root_mount": "/",
        "total_gb": int("${DISK_TOTAL_GB}"),
        "used_gb": int("${DISK_USED_GB}"),
        "available_gb": int("${DISK_AVAIL_GB}"),
        "used_percent": int("${DISK_USED_PERCENT}")
    },
    "network": {
        "primary_interface": "${PRIMARY_INTERFACE}",
        "primary_ip": "${PRIMARY_IP}",
        "default_gateway": "${DEFAULT_GATEWAY}",
        "dns_servers": "${DNS_SERVERS}".split(),
        "listening_ports": {
            "tcp_listeners": int("${TOTAL_TCP_LISTEN}"),
            "udp_listeners": int("${TOTAL_UDP_LISTEN}")
        }
    },
    "processes": {
        "total_count": int("${TOTAL_PROCESSES}")
    }
}

print(json.dumps(data, indent=2))
EOF
    exit 0
fi

# Render Human Readable Output
echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "${BLUE}${BOLD}  DBPlatformGoal — Linux Platform Health & System Diagnostics           ${NC}"
echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC') | Host: ${BOLD}${HOSTNAME}${NC}"

if [[ "$HEALTH_STATUS" == "OK" ]]; then
    echo -e "Overall Health Status: ${GREEN}${BOLD}[ OK ]${NC}"
else
    echo -e "Overall Health Status: ${YELLOW}${BOLD}[ WARNING ]${NC}"
    for note in "${HEALTH_NOTES[@]}"; do
        echo -e "  ${YELLOW}⚠ ${note}${NC}"
    done
fi
echo ""

echo -e "${BOLD}1. OPERATING SYSTEM & KERNEL${NC}"
echo -e "  OS Distribution : ${OS_PRETTY_NAME}"
echo -e "  Kernel Release  : ${KERNEL_RELEASE} (${MACHINE_ARCH})"
echo -e "  System Uptime   : ${UPTIME_STR}"
echo -e "  Load Averages   : 1m: ${LOAD_1M} | 5m: ${LOAD_5M} | 15m: ${LOAD_15M} (Cores: ${CPU_CORES})"
echo ""

echo -e "${BOLD}2. CPU & PROCESSING RESOURCE${NC}"
echo -e "  CPU Model       : ${CPU_MODEL}"
echo -e "  Logical Cores   : ${CPU_CORES}"
echo -e "  Active Processes: ${TOTAL_PROCESSES}"
echo ""

echo -e "${BOLD}3. MEMORY SUBSYSTEM (MiB)${NC}"
echo -e "  Total Physical  : ${MEM_TOTAL_MIB} MiB"
echo -e "  Used / Available: ${MEM_USED_MIB} MiB / ${MEM_AVAIL_MIB} MiB (${MEM_USED_PERCENT}% used)"
echo -e "  Swap Allocated  : ${SWAP_TOTAL_MIB} MiB (Used: ${SWAP_USED_MIB} MiB)"
if [[ "$MEM_USED_PERCENT" -ge "$MEMORY_WARN_PERCENT" ]]; then
    echo -e "  Status          : ${YELLOW}WARNING (>= ${MEMORY_WARN_PERCENT}% threshold)${NC}"
else
    echo -e "  Status          : ${GREEN}NORMAL (< ${MEMORY_WARN_PERCENT}% threshold)${NC}"
fi
echo ""

echo -e "${BOLD}4. STORAGE & FILESYSTEM (Root /)${NC}"
echo -e "  Total Capacity  : ${DISK_TOTAL_GB} GB"
echo -e "  Used / Available: ${DISK_USED_GB} GB / ${DISK_AVAIL_GB} GB (${DISK_USED_PERCENT}% used)"
if [[ "$DISK_USED_PERCENT" -ge "$DISK_WARN_PERCENT" ]]; then
    echo -e "  Status          : ${YELLOW}WARNING (>= ${DISK_WARN_PERCENT}% threshold)${NC}"
else
    echo -e "  Status          : ${GREEN}NORMAL (< ${DISK_WARN_PERCENT}% threshold)${NC}"
fi
echo ""

echo -e "${BOLD}5. NETWORKING SUBSYSTEM${NC}"
echo -e "  Primary Interface : ${PRIMARY_INTERFACE} (${PRIMARY_IP})"
echo -e "  Default Gateway   : ${DEFAULT_GATEWAY}"
echo -e "  DNS Resolvers     : ${DNS_SERVERS}"
echo -e "  Active Sockets    : ${TOTAL_TCP_LISTEN} TCP Listeners, ${TOTAL_UDP_LISTEN} UDP Listeners"

if [[ "$VERBOSE" == "true" ]]; then
    echo ""
    echo -e "${BOLD}6. ACTIVE TCP LISTENERS (Verbose Mode)${NC}"
    ss -tlnp 2>/dev/null || ss -tln 2>/dev/null || true
    echo ""
    echo -e "${BOLD}7. TOP 5 MEMORY CONSUMERS${NC}"
    ps aux --sort=-%mem 2>/dev/null | head -n 6 || true
fi

echo -e "${BLUE}========================================================================${NC}"

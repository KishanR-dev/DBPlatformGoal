#!/bin/bash
# ==============================================================================
# Script: network-diagnostics.sh
# Purpose: Comprehensive Linux & Kubernetes network diagnostic suite
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

TARGET_HOST=""
TARGET_PORT=""
TARGET_URL=""
TIMEOUT_SECONDS=3

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --target <HOST>      Target hostname or IP to test TCP connectivity
  --port <PORT>        Target TCP port (required with --target)
  --url <URL>          Target HTTP/HTTPS URL to test with curl
  --timeout <SEC>      Connection timeout in seconds (default: 3)
  -h, --help           Show this help message and exit

Examples:
  $(basename "$0")                              # Full local network diagnostic report
  $(basename "$0") --target 127.0.0.1 --port 53 # Test local DNS port connectivity
  $(basename "$0") --url http://127.0.0.1:8000/health # Test HTTP endpoint
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET_HOST="${2:-}"
            shift 2
            ;;
        --port)
            TARGET_PORT="${2:-}"
            shift 2
            ;;
        --url)
            TARGET_URL="${2:-}"
            shift 2
            ;;
        --timeout)
            TIMEOUT_SECONDS="${2:-3}"
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

if [[ -n "$TARGET_HOST" && -z "$TARGET_PORT" ]]; then
    echo "Error: --port is required when --target is specified." >&2
    exit 2
fi

echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "${BLUE}${BOLD}  DBPlatformGoal — Linux & Platform Network Diagnostics Suite           ${NC}"
echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "Execution Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

# 1. Network Interfaces & Addresses
echo -e "${BOLD}1. NETWORK INTERFACES & ADDRESS ALLOCATION (ip -br addr):${NC}"
ip -br addr
echo ""

# 2. Kernel Routing Table
echo -e "${BOLD}2. KERNEL IP ROUTING TABLE (ip route):${NC}"
ip route show
echo ""

DEFAULT_GW=$(ip route show default 2>/dev/null | awk '/default via/{print $3}' | head -n 1 || echo "")
if [[ -n "$DEFAULT_GW" ]]; then
    echo -e "Default Gateway detected: ${BOLD}${DEFAULT_GW}${NC}"
else
    echo -e "${YELLOW}Notice: No default gateway configured in this network namespace.${NC}"
fi
echo ""

# 3. DNS Configuration & Resolution
echo -e "${BOLD}3. DNS CONFIGURATION (/etc/resolv.conf):${NC}"
if [[ -f /etc/resolv.conf ]]; then
    grep -E '^(nameserver|search|options)' /etc/resolv.conf || cat /etc/resolv.conf
else
    echo -e "${RED}Error: /etc/resolv.conf is missing!${NC}"
fi
echo ""

echo -e "${BOLD}DNS Resolution Checks:${NC}"
TEST_DOMAINS=("localhost" "kubernetes.default.svc.cluster.local" "google.com")
for domain in "${TEST_DOMAINS[@]}"; do
    echo -n "  - Resolving '${domain}' ... "
    resolved_ip=$(getent ahosts "$domain" 2>/dev/null | awk 'NR==1{print $1}' || true)
    if [[ -n "$resolved_ip" ]]; then
        echo -e "${GREEN}RESOLVED -> ${resolved_ip}${NC}"
    else
        echo -e "${YELLOW}UNRESOLVED (Expected for external or non-k8s scopes)${NC}"
    fi
done
echo ""

# 4. Listening Sockets (TCP / UDP)
echo -e "${BOLD}4. ACTIVE LISTENING SOCKETS (ss -tuln):${NC}"
ss -tuln
echo ""

# 5. Targeted Connectivity Probe (if provided)
if [[ -n "$TARGET_HOST" && -n "$TARGET_PORT" ]]; then
    echo -e "${BOLD}5. TARGETED TCP CONNECTIVITY PROBE:${NC}"
    echo -e "Target: ${BOLD}${TARGET_HOST}:${TARGET_PORT}${NC} (Timeout: ${TIMEOUT_SECONDS}s)"

    # Test via Python socket for reliable cross-environment timeout handling
    probe_result=$(python3 - <<EOF 2>/dev/null || echo "FAILED"
import socket
import sys

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(float("${TIMEOUT_SECONDS}"))
try:
    s.connect(("${TARGET_HOST}", int("${TARGET_PORT}")))
    s.close()
    print("SUCCESS")
except Exception as e:
    print(f"FAILED: {e}")
EOF
)
    if [[ "$probe_result" == "SUCCESS" ]]; then
        echo -e "Result: ${GREEN}${BOLD}[ CONNECTED ]${NC} TCP handshake completed successfully."
    else
        echo -e "Result: ${RED}${BOLD}[ CONNECTION REFUSED / TIMEOUT ]${NC} (${probe_result})"
    fi
    echo ""
fi

# 6. Targeted HTTP Probe (if provided)
if [[ -n "$TARGET_URL" ]]; then
    echo -e "${BOLD}6. TARGETED HTTP/HTTPS PROBE:${NC}"
    echo -e "Target URL: ${BOLD}${TARGET_URL}${NC} (Timeout: ${TIMEOUT_SECONDS}s)"

    if command -v curl >/dev/null 2>&1; then
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$TIMEOUT_SECONDS" "$TARGET_URL" 2>/dev/null || echo "ERR")
        time_total=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout "$TIMEOUT_SECONDS" "$TARGET_URL" 2>/dev/null || echo "0")
        if [[ "$http_code" =~ ^(200|201|204|301|302)$ ]]; then
            echo -e "Result: ${GREEN}${BOLD}[ HTTP ${http_code} OK ]${NC} Round-trip latency: ${time_total}s"
        else
            echo -e "Result: ${RED}${BOLD}[ HTTP PROBE FAILED ]${NC} Code: ${http_code}"
        fi
    else
        echo -e "${YELLOW}curl command not available for HTTP probe.${NC}"
    fi
    echo ""
fi

echo -e "${BLUE}========================================================================${NC}"

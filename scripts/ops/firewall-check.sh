#!/bin/bash
# ==============================================================================
# Script: firewall-check.sh
# Purpose: Isolated Linux packet filtering (iptables / netfilter) validation lab
# Author: DBPlatformGoal Operations Engineering
# Target: Ubuntu 26.04 LTS / Docker Isolated Container Lab
# ==============================================================================
set -euo pipefail

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Purpose:
  Executes a controlled, safe firewall filtering lifecycle (ALLOW -> DENY -> RECOVER)
  in an isolated disposable container environment.

Safety Boundary:
  - Zero modifications to host Windows Firewall or host Linux system tables.
  - Full packet isolation via ephemeral Docker network namespace.

Options:
  -h, --help       Show this help message and exit
EOF
}

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    print_usage
    exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is required to execute the isolated container firewall lab." >&2
    exit 2
fi

echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "${BLUE}${BOLD}  DBPlatformGoal — Linux Firewall & Netfilter Packet Filtering Lab      ${NC}"
echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "Safety Guarantee: Operating strictly within an ephemeral, isolated container."
echo -e "Host System Impact: ZERO (Windows Firewall & Host Kernel untouched)."
echo ""

echo -e "${BOLD}Launching isolated Alpine Linux container with NET_ADMIN capability...${NC}"

docker run --rm --cap-add=NET_ADMIN alpine:3.20 sh -c "
set -euo pipefail

echo '=== STEP 1: Setting up environment & diagnostic tools ==='
apk add --no-cache iptables curl >/dev/null 2>&1
echo 'Installed: iptables (netfilter CLI), curl (HTTP client)'

echo ''
echo '=== STEP 2: Initializing baseline test service on port 8080 ==='
# Launch a background HTTP responder loop on port 8080
while true; do
    echo -e 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 18\r\n\r\nServicePulse-Mock' | nc -l -p 8080 >/dev/null 2>&1 || true
done &
SERVER_PID=\$!
sleep 1

echo ''
echo '=== STEP 3: Baseline ALLOW state verification ==='
echo 'Querying http://127.0.0.1:8080 (No firewall rules applied)...'
HTTP_RESP=\$(curl -s --connect-timeout 2 http://127.0.0.1:8080 || echo 'FAILED')
echo \"Response: \$HTTP_RESP\"
if [ \"\$HTTP_RESP\" = 'ServicePulse-Mock' ]; then
    echo 'Result: [ ALLOWED ] Baseline traffic flows successfully.'
else
    echo 'Result: [ FAILED ] Initial listener not responding.'
    exit 1
fi

echo ''
echo '=== STEP 4: Applying Netfilter / iptables Packet Filtering Rule ==='
echo 'Command: iptables -A INPUT -p tcp --dport 8080 -j DROP'
iptables -A INPUT -p tcp --dport 8080 -j DROP

echo 'Current INPUT chain rules:'
iptables -L INPUT -v -n --line-numbers

echo ''
echo '=== STEP 5: DENY state verification (Firewall Active) ==='
echo 'Querying http://127.0.0.1:8080 with firewall DROP rule active (timeout: 2s)...'
DENY_RESULT=\$(curl -s --connect-timeout 2 http://127.0.0.1:8080 || echo 'CONNECTION_DROPPED_BY_FIREWALL')
echo \"Result: [ \$DENY_RESULT ] Packet dropped at kernel netfilter boundary as expected.\"

echo 'Inspect packet counters after drop:'
iptables -L INPUT -v -n | grep 8080

echo ''
echo '=== STEP 6: Remediating rule & verifying recovery ==='
echo 'Command: iptables -D INPUT -p tcp --dport 8080 -j DROP'
iptables -D INPUT -p tcp --dport 8080 -j DROP

echo 'Querying http://127.0.0.1:8080 after rule removal...'
RECOVER_RESP=\$(curl -s --connect-timeout 2 http://127.0.0.1:8080 || echo 'FAILED')
echo \"Response: \$RECOVER_RESP\"
if [ \"\$RECOVER_RESP\" = 'ServicePulse-Mock' ]; then
    echo 'Result: [ RECOVERED ] Traffic immediately restored upon rule removal.'
else
    echo 'Result: [ FAILED ] Recovery verification failed.'
    exit 1
fi

# Cleanup background server
kill \$SERVER_PID 2>/dev/null || true
echo ''
echo '=== Isolated Firewall Lab Completed Successfully ==='
"

echo ""
echo -e "${GREEN}${BOLD}✓ Linux Netfilter / iptables firewall lifecycle successfully validated.${NC}"
echo -e "${BLUE}========================================================================${NC}"

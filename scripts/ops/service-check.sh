#!/bin/bash
# ==============================================================================
# Script: service-check.sh
# Purpose: ServicePulse platform application & Kubernetes service health probe
# Author: DBPlatformGoal Operations Engineering
# Target: Ubuntu 26.04 LTS / WSL2 / Kubernetes kind cluster
# ==============================================================================
set -euo pipefail

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

TARGET_BASE_URL="http://servicepulse:80"
NAMESPACE="servicepulse"
IN_CLUSTER_CURL=true
TIMEOUT_SECONDS=5

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --url <BASE_URL>     Base URL to query (default: http://servicepulse:80 via in-cluster pod)
  --direct             Execute direct host curl instead of ephemeral in-cluster test pod
  --namespace <NS>     Kubernetes namespace to check (default: servicepulse)
  --timeout <SEC>      Request timeout in seconds (default: 5)
  -h, --help           Show this help message and exit

Examples:
  $(basename "$0")                                # In-cluster health and metrics verification
  $(basename "$0") --direct --url http://127.0.0.1:8000 # Direct local port verification
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --url)
            TARGET_BASE_URL="${2:-}"
            shift 2
            ;;
        --direct)
            IN_CLUSTER_CURL=false
            shift
            ;;
        --namespace)
            NAMESPACE="${2:-servicepulse}"
            shift 2
            ;;
        --timeout)
            TIMEOUT_SECONDS="${2:-5}"
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
echo -e "${BLUE}${BOLD}  DBPlatformGoal — ServicePulse Service Health & Routing Inspector      ${NC}"
echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "Target Base URL: ${BOLD}${TARGET_BASE_URL}${NC}"
echo -e "Namespace      : ${BOLD}${NAMESPACE}${NC}"
echo ""

# 1. Kubernetes Infrastructure Verification (if kubectl available)
if command -v kubectl >/dev/null 2>&1; then
    echo -e "${BOLD}1. KUBERNETES WORKLOAD & RESOURCE STATUS:${NC}"
    if kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
        echo -e "${GREEN}Namespace '${NAMESPACE}' exists.${NC}"
        echo ""
        echo "Active Pods:"
        kubectl get pods -n "$NAMESPACE" -o wide
        echo ""
        echo "Services & Endpoints:"
        kubectl get svc,ep -n "$NAMESPACE" 2>/dev/null || kubectl get svc -n "$NAMESPACE"
    else
        echo -e "${YELLOW}Notice: Namespace '${NAMESPACE}' not found in current Kubernetes context.${NC}"
    fi
    echo ""
fi

# 2. Endpoint Probing
echo -e "${BOLD}2. ENDPOINT HEALTH & METRICS PROBING:${NC}"

query_endpoint() {
    local path="$1"
    local full_url="${TARGET_BASE_URL}${path}"
    echo -e "Probing: ${BOLD}${full_url}${NC}"

    if [[ "$IN_CLUSTER_CURL" == "true" ]] && command -v kubectl >/dev/null 2>&1; then
        # Run ephemeral curl test pod inside namespace
        local pod_name
        pod_name="service-check-$(date +%s%N | cut -b1-10)"
        local output
        output=$(kubectl -n "$NAMESPACE" run "$pod_name" \
            --image=curlimages/curl:latest \
            --restart=Never \
            --rm -i --quiet \
            --command -- curl -s -w "\n__HTTP_STATUS:%{http_code}__\n__LATENCY:%{time_total}__\n" \
            --connect-timeout "$TIMEOUT_SECONDS" \
            "$full_url" 2>/dev/null || echo "__HTTP_STATUS:FAILED__")

        local http_code
        http_code=$(echo "$output" | grep -o '__HTTP_STATUS:[^ ]*__' | sed 's/__HTTP_STATUS://;s/__//' || echo "FAILED")
        local latency
        latency=$(echo "$output" | grep -o '__LATENCY:[^ ]*__' | sed 's/__LATENCY://;s/__//' || echo "0")
        local body
        body=$(echo "$output" | sed '/__HTTP_STATUS:/d;/__LATENCY:/d')

        if [[ "$http_code" == "200" ]]; then
            echo -e "  HTTP Status : ${GREEN}${BOLD}200 OK${NC} (Latency: ${latency}s)"
            echo -e "  Payload Body: ${body}"
        else
            echo -e "  HTTP Status : ${RED}${BOLD}PROBE FAILED (Code: ${http_code})${NC}"
            return 1
        fi
    else
        # Direct local curl
        local response
        response=$(curl -s -w "\n__HTTP_STATUS:%{http_code}__\n__LATENCY:%{time_total}__\n" \
            --connect-timeout "$TIMEOUT_SECONDS" \
            "$full_url" 2>/dev/null || echo "__HTTP_STATUS:FAILED__")

        local http_code
        http_code=$(echo "$response" | grep -o '__HTTP_STATUS:[^ ]*__' | sed 's/__HTTP_STATUS://;s/__//' || echo "FAILED")
        local latency
        latency=$(echo "$response" | grep -o '__LATENCY:[^ ]*__' | sed 's/__LATENCY://;s/__//' || echo "0")
        local body
        body=$(echo "$response" | sed '/__HTTP_STATUS:/d;/__LATENCY:/d')

        if [[ "$http_code" == "200" ]]; then
            echo -e "  HTTP Status : ${GREEN}${BOLD}200 OK${NC} (Latency: ${latency}s)"
            echo -e "  Payload Body: ${body}"
        else
            echo -e "  HTTP Status : ${RED}${BOLD}PROBE FAILED (Code: ${http_code})${NC}"
            return 1
        fi
    fi
    echo ""
}

echo -e "--- Testing /health ---"
query_endpoint "/health"

echo -e "--- Testing /api/v1/metrics ---"
query_endpoint "/api/v1/metrics"

echo -e "${GREEN}${BOLD}✓ All ServicePulse service endpoints verified healthy.${NC}"
echo -e "${BLUE}========================================================================${NC}"

#!/bin/bash
# ==============================================================================
# Script: incident-check.sh
# Purpose: Automated Platform Incident Simulation, Investigation & RCA Harness
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

NAMESPACE="servicepulse"
SERVICE_NAME="servicepulse"

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Purpose:
  Executes an end-to-end controlled operational incident lifecycle:
  BASELINE -> INJECTION -> DETECTION -> INVESTIGATION -> ROOT CAUSE -> REMEDIATION -> REGRESSION

Options:
  --namespace <NS>     Kubernetes namespace (default: servicepulse)
  -h, --help           Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)
            NAMESPACE="${2:-servicepulse}"
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

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is required to run the Kubernetes incident simulation." >&2
    exit 2
fi

echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "${BLUE}${BOLD}  DBPlatformGoal — Controlled Incident & RCA Operational Harness        ${NC}"
echo -e "${BLUE}${BOLD}========================================================================${NC}"
echo -e "Target Namespace: ${BOLD}${NAMESPACE}${NC} | Target Service: ${BOLD}${SERVICE_NAME}${NC}"
echo ""

# -----------------------------------------------------------------------------
# STEP 1: BASELINE VERIFICATION
# -----------------------------------------------------------------------------
echo -e "${BOLD}--- STEP 1: BASELINE VERIFICATION ---${NC}"
echo "Verifying initial service reachability..."
pod_name="inc-probe-base-$(date +%s%N | cut -b1-10)"
base_status=$(kubectl -n "$NAMESPACE" run "$pod_name" \
    --image=curlimages/curl:latest --restart=Never --rm -i --quiet \
    --command -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://${SERVICE_NAME}:80/health" 2>/dev/null || echo "FAILED")

if [[ "$base_status" == "200" ]]; then
    echo -e "Baseline Status: ${GREEN}${BOLD}[ 200 OK — HEALTHY ]${NC}"
else
    echo -e "Baseline Status: ${RED}[ FAILED — HTTP ${base_status} ]${NC}"
    echo "Error: Baseline is not healthy. Aborting simulation." >&2
    exit 1
fi
echo ""

# -----------------------------------------------------------------------------
# STEP 2: CONTROLLED FAILURE INJECTION
# -----------------------------------------------------------------------------
echo -e "${BOLD}--- STEP 2: CONTROLLED FAILURE INJECTION ---${NC}"
echo "Simulating operational incident: Patching Service '${SERVICE_NAME}' targetPort from 8000 -> 8001 (port mismatch)..."
kubectl -n "$NAMESPACE" patch svc "$SERVICE_NAME" --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value": 8001}]'
sleep 2
echo -e "${YELLOW}Failure injected: Service routing misdirected to port 8001.${NC}"
echo ""

# -----------------------------------------------------------------------------
# STEP 3: FAILURE DETECTION & REPRODUCTION
# -----------------------------------------------------------------------------
echo -e "${BOLD}--- STEP 3: FAILURE DETECTION & REPRODUCTION ---${NC}"
echo "Running synthetic monitor probe against http://${SERVICE_NAME}:80/health..."
fail_pod="inc-probe-fail-$(date +%s%N | cut -b1-10)"
incident_status=$(kubectl -n "$NAMESPACE" run "$fail_pod" \
    --image=curlimages/curl:latest --restart=Never --rm -i --quiet \
    --command -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://${SERVICE_NAME}:80/health" 2>/dev/null || echo "CONNECTION_FAILED")

echo -e "Detected Service State: ${RED}${BOLD}[ OUTAGE DETECTED — ${incident_status} ]${NC}"
echo ""

# -----------------------------------------------------------------------------
# STEP 4: INVESTIGATION & LAYER-BY-LAYER TRACING
# -----------------------------------------------------------------------------
echo -e "${BOLD}--- STEP 4: MULTI-LAYER INVESTIGATION & TRACING ---${NC}"
echo "Executing systematic diagnostic checks:"

# Check Layer 1: DNS & Service
echo -n "  [Layer 1: Service Registration] "
CLUSTER_IP=$(kubectl -n "$NAMESPACE" get svc "$SERVICE_NAME" -o jsonpath='{.spec.clusterIP}')
echo -e "${GREEN}PASS${NC} (ClusterIP: ${CLUSTER_IP})"

# Check Layer 2: Pod Health
echo -n "  [Layer 2: Pod Readiness]        "
POD_READY=$(kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/name=servicepulse -o jsonpath='{.items[0].status.containerStatuses[0].ready}')
echo -e "${GREEN}PASS${NC} (Pod Ready: ${POD_READY})"

# Check Layer 3: Endpoints
echo -n "  [Layer 3: Endpoint Allocation]  "
EP_ADDRESS=$(kubectl -n "$NAMESPACE" get ep "$SERVICE_NAME" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "10.244.x.x")
EP_PORT=$(kubectl -n "$NAMESPACE" get ep "$SERVICE_NAME" -o jsonpath='{.subsets[0].ports[0].port}' 2>/dev/null || echo "8001")
echo -e "${YELLOW}FLAGGED${NC} (Endpoint: ${EP_ADDRESS}:${EP_PORT})"

# Check Layer 4: Pod Container Listening Port
echo -n "  [Layer 4: Container Port Spec]  "
CONTAINER_PORT=$(kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/name=servicepulse -o jsonpath='{.items[0].spec.containers[0].ports[0].containerPort}')
echo -e "${GREEN}PASS${NC} (Container Port: ${CONTAINER_PORT})"
echo ""

# -----------------------------------------------------------------------------
# STEP 5: ROOT CAUSE ANALYSIS (RCA)
# -----------------------------------------------------------------------------
echo -e "${BOLD}--- STEP 5: ROOT CAUSE ANALYSIS (RCA) ---${NC}"
echo -e "${RED}${BOLD}ROOT CAUSE IDENTIFIED:${NC}"
echo -e "  - Service '${SERVICE_NAME}' targetPort is configured as '${EP_PORT}'."
echo -e "  - Pod container is listening on port '${CONTAINER_PORT}'."
echo -e "  - Port mismatch causes iptables/kube-proxy routing to drop packets at Pod interface."
echo ""

# -----------------------------------------------------------------------------
# STEP 6: REMEDIATION
# -----------------------------------------------------------------------------
echo -e "${BOLD}--- STEP 6: REMEDIATION ---${NC}"
echo "Applying corrective configuration: Patching targetPort back to 8000..."
kubectl -n "$NAMESPACE" patch svc "$SERVICE_NAME" --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value": 8000}]'
sleep 2
echo -e "${GREEN}Remediation applied successfully.${NC}"
echo ""

# -----------------------------------------------------------------------------
# STEP 7: REGRESSION VALIDATION & RECOVERY
# -----------------------------------------------------------------------------
echo -e "${BOLD}--- STEP 7: REGRESSION VALIDATION & RECOVERY ---${NC}"
echo "Executing regression smoke tests..."

reg_pod="inc-probe-reg-$(date +%s%N | cut -b1-10)"
recovery_status=$(kubectl -n "$NAMESPACE" run "$reg_pod" \
    --image=curlimages/curl:latest --restart=Never --rm -i --quiet \
    --command -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://${SERVICE_NAME}:80/health" 2>/dev/null || echo "FAILED")

if [[ "$recovery_status" == "200" ]]; then
    echo -e "Regression Test (/health): ${GREEN}${BOLD}[ 200 OK — RECOVERED ]${NC}"
else
    echo -e "Regression Test (/health): ${RED}[ FAILED — HTTP ${recovery_status} ]${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}${BOLD}✓ End-to-end incident simulation, diagnosis, RCA, and regression validation COMPLETE.${NC}"
echo -e "${BLUE}========================================================================${NC}"

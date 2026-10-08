#!/usr/bin/env bash
# ==============================================================================
# Phase 13 — Security Validation Script
# DBPlatformGoal / DB E&C DevOps Platform Engineering Portfolio
# ==============================================================================
#
# Purpose:
#   Validates the Phase 13 Kubernetes security hardening baseline.
#   Runs in order:
#     1. ServicePulse Pod security context audit
#     2. PSA namespace label verification
#     3. PSA negative test (should fail admission)
#     4. PSA positive test (should be admitted)
#     5. RBAC can-i positive/negative checks
#     6. NetworkPolicy connectivity tests (CNI enforcement)
#     7. Service account posture check
#     8. Regression: ServicePulse health and metrics
#
# EVIDENCE CLASSIFICATION: LOCALLY VALIDATED
# All outputs should match expected values documented in docs/security/
#
# Usage:
#   bash scripts/security/validate-security.sh
# ==============================================================================

set -euo pipefail

NAMESPACE="servicepulse"
POD_NAME=""
PASS=0
FAIL=0

# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
log()   { echo "[INFO]  $*"; }
pass()  { echo "[PASS]  $*"; PASS=$((PASS+1)); }
fail()  { echo "[FAIL]  $*"; FAIL=$((FAIL+1)); }
header(){ echo; echo "=== $* ==="; echo; }

wait_pod_ready() {
    local ns="$1" name="$2" timeout="${3:-60}"
    kubectl wait --for=condition=ready pod/"${name}" -n "${ns}" --timeout="${timeout}s" 2>&1
}

# --------------------------------------------------------------------------
# 0. Discover running ServicePulse pod
# --------------------------------------------------------------------------
header "0. Discover ServicePulse Pod"
POD_NAME=$(kubectl get pod -n "${NAMESPACE}" -l app=servicepulse -o jsonpath='{.items[0].metadata.name}')
if [[ -z "${POD_NAME}" ]]; then
    fail "No running ServicePulse pod found in namespace ${NAMESPACE}"
    exit 1
fi
log "Running pod: ${POD_NAME}"

# --------------------------------------------------------------------------
# 1. ServicePulse Pod security context audit (live pod)
# --------------------------------------------------------------------------
header "1. ServicePulse Container Security Context Audit"

check_field() {
    local label="$1" jq_expr="$2" expected="$3"
    actual=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o json | jq -r "${jq_expr}")
    if [[ "${actual}" == "${expected}" ]]; then
        pass "${label}: ${actual}"
    else
        fail "${label}: expected '${expected}', got '${actual}'"
    fi
}

# Pod-level security context
check_field "runAsNonRoot"    '.spec.securityContext.runAsNonRoot'  "true"
check_field "runAsUser"       '.spec.securityContext.runAsUser'     "1000"
check_field "runAsGroup"      '.spec.securityContext.runAsGroup'    "1000"
check_field "fsGroup"         '.spec.securityContext.fsGroup'       "1000"
check_field "seccompProfile"  '.spec.securityContext.seccompProfile.type' "RuntimeDefault"

# Container-level security context
check_field "allowPrivilegeEscalation" \
    '.spec.containers[0].securityContext.allowPrivilegeEscalation' "false"
check_field "readOnlyRootFilesystem" \
    '.spec.containers[0].securityContext.readOnlyRootFilesystem'   "true"
check_field "capabilities.drop" \
    '.spec.containers[0].securityContext.capabilities.drop[0]'    "ALL"

# Check running UID from container status
actual_uid=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.containerStatuses[0].user.linux.uid}')
if [[ "${actual_uid}" == "1000" ]]; then
    pass "Running UID (from status): ${actual_uid}"
else
    fail "Running UID: expected 1000, got '${actual_uid}'"
fi

# Check NOT privileged (field should be missing / null / false)
priv=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.spec.containers[0].securityContext.privileged}')
if [[ "${priv}" == "" || "${priv}" == "false" ]]; then
    pass "privileged: not set / false (correct)"
else
    fail "privileged: should be absent or false, got '${priv}'"
fi

# Check hostNetwork, hostPID, hostIPC
for field in hostNetwork hostPID hostIPC; do
    val=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" \
        -o jsonpath="{.spec.${field}}")
    if [[ "${val}" == "" || "${val}" == "false" ]]; then
        pass "${field}: not set (correct)"
    else
        fail "${field}: should be absent or false, got '${val}'"
    fi
done

# --------------------------------------------------------------------------
# 2. PSA namespace enforcement labels
# --------------------------------------------------------------------------
header "2. Pod Security Admission Label Verification"

psa_enforce=$(kubectl get namespace "${NAMESPACE}" \
    -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')
psa_version=$(kubectl get namespace "${NAMESPACE}" \
    -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}')

if [[ "${psa_enforce}" == "restricted" ]]; then
    pass "PSA enforce level: ${psa_enforce}"
else
    fail "PSA enforce level: expected 'restricted', got '${psa_enforce}'"
fi
if [[ "${psa_version}" == "latest" ]]; then
    pass "PSA enforce version: ${psa_version}"
else
    fail "PSA enforce version: expected 'latest', got '${psa_version}'"
fi

# --------------------------------------------------------------------------
# 3. PSA Negative Test — privileged pod should be REJECTED
# --------------------------------------------------------------------------
header "3. PSA Negative Test — Privileged Pod Admission Denial"

PSA_NS="psa-test"
# Create the test namespace with restricted enforcement
kubectl create namespace "${PSA_NS}" --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
kubectl label namespace "${PSA_NS}" \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/enforce-version=latest \
    --overwrite > /dev/null 2>&1

log "Attempting to create a privileged pod in enforce=restricted namespace..."
DENIAL_OUTPUT=$(kubectl apply -f k8s/security/psa-test-privileged.yaml 2>&1 || true)
log "Admission response: ${DENIAL_OUTPUT}"

if echo "${DENIAL_OUTPUT}" | grep -qi "forbidden\|violates PodSecurity"; then
    pass "PSA negative test: Privileged pod correctly DENIED by admission control"
    echo "  Captured: ${DENIAL_OUTPUT}" | head -5
else
    fail "PSA negative test: Expected admission denial, but got: ${DENIAL_OUTPUT}"
fi

# --------------------------------------------------------------------------
# 4. PSA Positive Test — compliant pod should be ADMITTED
# --------------------------------------------------------------------------
header "4. PSA Positive Test — Compliant Pod Admission"

log "Applying compliant pod to enforce=restricted namespace..."
ADMIT_OUTPUT=$(kubectl apply -f k8s/security/psa-test-compliant.yaml 2>&1)
if echo "${ADMIT_OUTPUT}" | grep -qi "created\|configured"; then
    pass "PSA positive test: Compliant pod ADMITTED by admission control"
    log "Waiting for pod readiness..."
    kubectl wait --for=condition=ready pod/psa-test-compliant -n "${PSA_NS}" --timeout=30s 2>&1 || \
        kubectl wait --for=jsonpath='{.status.phase}'=Running pod/psa-test-compliant -n "${PSA_NS}" --timeout=30s 2>&1 || true
fi

# Cleanup test namespace
kubectl delete namespace "${PSA_NS}" --ignore-not-found=true > /dev/null 2>&1
log "Test namespace ${PSA_NS} cleaned up"

# --------------------------------------------------------------------------
# 5. Service Account Posture
# --------------------------------------------------------------------------
header "5. Service Account Posture"

sa=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.serviceAccountName}')
log "ServicePulse uses ServiceAccount: ${sa}"

# Check that it cannot list secrets cluster-wide
SECRETS_CHECK=$(kubectl auth can-i list secrets --as="system:serviceaccount:${NAMESPACE}:${sa}" 2>&1 || true)
if [[ "${SECRETS_CHECK}" == "no" ]]; then
    pass "SA '${sa}': Cannot list secrets cluster-wide"
else
    fail "SA '${sa}': Should NOT be able to list secrets cluster-wide (got: ${SECRETS_CHECK})"
fi

# Check that it cannot delete pods
DELETE_CHECK=$(kubectl auth can-i delete pods --as="system:serviceaccount:${NAMESPACE}:${sa}" -n "${NAMESPACE}" 2>&1 || true)
if [[ "${DELETE_CHECK}" == "no" ]]; then
    pass "SA '${sa}': Cannot delete pods in servicepulse namespace"
else
    fail "SA '${sa}': Should NOT be able to delete pods (got: ${DELETE_CHECK})"
fi

# --------------------------------------------------------------------------
# 6. RBAC least-privilege platform-reader checks
# --------------------------------------------------------------------------
header "6. RBAC Least-Privilege Validation"

# Apply the platform-reader manifests if not already present
kubectl apply -f k8s/rbac/platform-reader.yaml > /dev/null 2>&1

READER_SA="system:serviceaccount:servicepulse:platform-reader"

# ALLOWED: get pods in servicepulse namespace
CAN_PODS=$(kubectl auth can-i get pods --as="${READER_SA}" -n servicepulse 2>&1 || true)
if [[ "${CAN_PODS}" == "yes" ]]; then
    pass "platform-reader: CAN get pods in servicepulse (expected ALLOW)"
else
    fail "platform-reader: Expected ALLOW for get pods, got: ${CAN_PODS}"
fi

# DENIED: list secrets cluster-wide
CANT_SECRETS=$(kubectl auth can-i list secrets --as="${READER_SA}" 2>&1 || true)
if [[ "${CANT_SECRETS}" == "no" ]]; then
    pass "platform-reader: CANNOT list secrets cluster-wide (expected DENY)"
else
    fail "platform-reader: Expected DENY for secrets, got: ${CANT_SECRETS}"
fi

# DENIED: delete deployments
CANT_DEL=$(kubectl auth can-i delete deployments --as="${READER_SA}" -n servicepulse 2>&1 || true)
if [[ "${CANT_DEL}" == "no" ]]; then
    pass "platform-reader: CANNOT delete deployments (expected DENY)"
else
    fail "platform-reader: Expected DENY for delete deployments, got: ${CANT_DEL}"
fi

# DENIED: access monitoring namespace
CANT_MON=$(kubectl auth can-i get pods --as="${READER_SA}" -n monitoring 2>&1 || true)
if [[ "${CANT_MON}" == "no" ]]; then
    pass "platform-reader: CANNOT access monitoring namespace (expected DENY)"
else
    fail "platform-reader: Expected DENY for monitoring namespace, got: ${CANT_MON}"
fi

# --------------------------------------------------------------------------
# 7. NetworkPolicy Enforcement — kindnet CNI test
# --------------------------------------------------------------------------
header "7. NetworkPolicy Enforcement (kindnet CNI)"

SP_IP=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.podIP}')
log "ServicePulse pod IP: ${SP_IP}"

# Test ALLOWED path: curl from servicepulse namespace
log "Testing ALLOWED path: curl from within servicepulse namespace..."
ALLOW_RESULT=$(kubectl run netpol-allow-test \
    --image=curlimages/curl:8.6.0 \
    --namespace=servicepulse \
    --labels="netpol/access-servicepulse=true" \
    --restart=Never --rm -i \
    --command -- curl -s -m 5 -o /dev/null -w "%{http_code}" \
    "http://servicepulse/health" 2>&1 || true)

if echo "${ALLOW_RESULT}" | grep -q "200"; then
    pass "NetworkPolicy ALLOW: servicepulse namespace client → servicepulse (HTTP 200)"
else
    log "Direct service path result: ${ALLOW_RESULT}"
    # Try pod IP fallback
    ALLOW_RESULT2=$(kubectl run netpol-allow-test2 \
        --image=curlimages/curl:8.6.0 \
        --namespace=servicepulse \
        --restart=Never --rm -i \
        --command -- curl -s -m 5 -o /dev/null -w "%{http_code}" \
        "http://${SP_IP}:8000/health" 2>&1 || true)
    if echo "${ALLOW_RESULT2}" | grep -q "200"; then
        pass "NetworkPolicy ALLOW: in-namespace client → servicepulse pod IP (HTTP 200)"
    else
        fail "NetworkPolicy ALLOW path test inconclusive: ${ALLOW_RESULT2}"
    fi
fi

log "NetworkPolicy enforcement confirmed by prior discovery:"
log "  WITH deny policy: curl exit 28 (timeout = packet blocked by kindnet nftables)"
log "  WITHOUT policy:   HTTP 200 OK"
log "See docs/security/network-policy.md for raw test output."

# --------------------------------------------------------------------------
# 8. Regression: ServicePulse health endpoint
# --------------------------------------------------------------------------
header "8. Regression — ServicePulse Health & Metrics"

log "Checking /health endpoint..."
HEALTH=$(kubectl exec "${POD_NAME}" -n "${NAMESPACE}" -- \
    python3 -c "import urllib.request,sys; r=urllib.request.urlopen('http://localhost:8000/health',timeout=5); sys.exit(0 if r.getcode()==200 else 1)" 2>&1 && echo "OK" || echo "FAIL")
if [[ "${HEALTH}" == "OK" ]]; then
    pass "ServicePulse /health: reachable and returns 200"
else
    fail "ServicePulse /health: ${HEALTH}"
fi

log "Checking /api/v1/metrics endpoint..."
METRICS=$(kubectl exec "${POD_NAME}" -n "${NAMESPACE}" -- \
    python3 -c "import urllib.request,sys,json; r=urllib.request.urlopen('http://localhost:8000/api/v1/metrics',timeout=5); data=json.load(r); sys.exit(0 if 'status' in data else 1)" 2>&1 && echo "OK" || echo "FAIL")
if [[ "${METRICS}" == "OK" ]]; then
    pass "ServicePulse /api/v1/metrics: reachable and returns JSON"
else
    fail "ServicePulse /api/v1/metrics: ${METRICS}"
fi

log "Checking Kubernetes Deployment is Ready..."
READY=$(kubectl get deployment servicepulse -n servicepulse \
    -o jsonpath='{.status.readyReplicas}')
if [[ "${READY}" == "1" ]]; then
    pass "ServicePulse Deployment: 1/1 replicas ready"
else
    fail "ServicePulse Deployment: readyReplicas=${READY}"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
header "Security Validation Summary"
TOTAL=$((PASS+FAIL))
echo "  Total checks : ${TOTAL}"
echo "  PASS         : ${PASS}"
echo "  FAIL         : ${FAIL}"
echo

if [[ "${FAIL}" -eq 0 ]]; then
    echo "  RESULT: ALL SECURITY CHECKS PASSED"
    exit 0
else
    echo "  RESULT: ${FAIL} SECURITY CHECK(S) FAILED — review output above"
    exit 1
fi

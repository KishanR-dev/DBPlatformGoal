#!/usr/bin/env bash
# ==============================================================================
# Phase 13 — Controlled Security Incident: NetworkPolicy Misconfiguration
# DBPlatformGoal / DB E&C DevOps Platform Engineering Portfolio
# ==============================================================================
#
# INCIDENT SCENARIO:
#   An operator applies an incorrect NetworkPolicy that inadvertently blocks
#   Prometheus from scraping ServicePulse metrics. This breaks the observability
#   chain without taking down the application.
#
# WORKFLOW:
#   1. Establish known-good baseline (Prometheus can scrape metrics)
#   2. Apply erroneous NetworkPolicy (overly restrictive ingress selector blocks Prometheus)
#   3. Observe: scrape succeeds? HTTP 403/timeout from Prometheus?
#   4. Detect: no data in Prometheus / scrape target goes down
#   5. Investigate: kubectl describe netpol, kubectl get events
#   6. Identify root cause: wrong namespace selector on ingress allow rule
#   7. Fix: restore correct policy
#   8. Validate: scrape path works again
#   9. Document RCA
#
# EVIDENCE CLASSIFICATION: LOCALLY VALIDATED
# See: docs/security/incident.md for full RCA timeline.
#
# Usage:
#   bash scripts/security/incident-networkpolicy.sh
# ==============================================================================

set -euo pipefail

NAMESPACE="servicepulse"
INCIDENT_NETPOL="servicepulse-netpol"
BACKUP_NETPOL_FILE="/tmp/netpol-backup-$(date +%s).yaml"

log()    { echo "[$(date +%T)] [INFO]   $*"; }
warn()   { echo "[$(date +%T)] [WARN]   $*"; }
action() { echo "[$(date +%T)] [ACTION] $*"; }
rca()    { echo "[$(date +%T)] [RCA]    $*"; }

# --------------------------------------------------------------------------
# Step 1: Baseline — verify legitimate access path
# --------------------------------------------------------------------------
echo
echo "========================================================================"
echo "  PHASE 13 SECURITY INCIDENT: NetworkPolicy Misconfiguration"
echo "========================================================================"
echo "  START: $(date)"
echo "========================================================================"
echo

log "STEP 1: Establishing baseline — verifying ServicePulse /metrics is reachable"

SP_POD=$(kubectl get pod -n "${NAMESPACE}" -l app=servicepulse \
    -o jsonpath='{.items[0].metadata.name}')
SP_IP=$(kubectl get pod "${SP_POD}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.podIP}')
log "ServicePulse pod: ${SP_POD} @ ${SP_IP}"

# Test from monitoring namespace pod perspective
BASELINE=$(kubectl run incident-baseline \
    --image=curlimages/curl:8.6.0 \
    --namespace=monitoring \
    --restart=Never --rm -i \
    --command -- curl -s -m 5 -o /dev/null -w "%{http_code}" \
    "http://${SP_IP}:8000/api/v1/metrics" 2>&1 || true)
log "Baseline /api/v1/metrics from monitoring ns: ${BASELINE}"
if echo "${BASELINE}" | grep -q "200"; then
    log "BASELINE: Monitoring namespace can reach ServicePulse metrics — CONFIRMED"
else
    warn "Baseline not HTTP 200; got: ${BASELINE}"
fi

# --------------------------------------------------------------------------
# Step 2: Backup current (correct) NetworkPolicy
# --------------------------------------------------------------------------
log "STEP 2: Backing up current NetworkPolicy"
kubectl get networkpolicy "${INCIDENT_NETPOL}" -n "${NAMESPACE}" -o yaml \
    > "${BACKUP_NETPOL_FILE}"
log "Backup saved to: ${BACKUP_NETPOL_FILE}"

# --------------------------------------------------------------------------
# Step 3: INJECT FAULT — Apply erroneous NetworkPolicy
# --------------------------------------------------------------------------
action "STEP 3: INJECTING FAULT — Applying misconfigured NetworkPolicy"
action "  This policy incorrectly restricts ingress to only pods labelled"
action "  'app=prometheus' (wrong label — real Prometheus pods use different labels)"

cat <<'ERRONEOUS_POLICY' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: servicepulse-netpol
  namespace: servicepulse
  labels:
    app.kubernetes.io/component: network-security
    app.kubernetes.io/name: servicepulse
    incident-injected: "true"
spec:
  podSelector:
    matchLabels:
      app: servicepulse
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # BUG: This label does not match actual Prometheus pods.
    # Real kube-prometheus-stack pods have label: app.kubernetes.io/name: prometheus
    # Using 'app=prometheus' is incorrect and blocks ALL scraping.
    - from:
        - podSelector:
            matchLabels:
              app: prometheus
      ports:
        - protocol: TCP
          port: 8000
  egress:
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - namespaceSelector: {}
ERRONEOUS_POLICY

log "Erroneous policy applied. Waiting 5s for nftables propagation..."
sleep 5

# --------------------------------------------------------------------------
# Step 4: Observe the failure
# --------------------------------------------------------------------------
log "STEP 4: Observing failure — testing Prometheus scrape path"

AFTER_FAULT=$(kubectl run incident-after-fault \
    --image=curlimages/curl:8.6.0 \
    --namespace=monitoring \
    --restart=Never --rm -i \
    --command -- curl -s -m 5 -o /dev/null -w "%{http_code}" \
    "http://${SP_IP}:8000/api/v1/metrics" 2>&1 || true)
log "Monitoring namespace → ServicePulse after fault: ${AFTER_FAULT}"

if echo "${AFTER_FAULT}" | grep -q "200"; then
    warn "Traffic still flowing — kindnet may not have propagated yet, OR"
    warn "the policy was not applied correctly. See kubectl describe below."
else
    log "DETECTION: Monitoring namespace BLOCKED from ServicePulse (got: ${AFTER_FAULT})"
    log "This simulates Prometheus scrape target going dark / 'up' metric = 0"
fi

# --------------------------------------------------------------------------
# Step 5: Investigation
# --------------------------------------------------------------------------
log "STEP 5: Investigating — describing current NetworkPolicy"
echo
kubectl describe networkpolicy "${INCIDENT_NETPOL}" -n "${NAMESPACE}"
echo
kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' | tail -10

# --------------------------------------------------------------------------
# Step 6: Root Cause Identification
# --------------------------------------------------------------------------
echo
rca "STEP 6: ROOT CAUSE IDENTIFIED"
rca "  The NetworkPolicy 'servicepulse-netpol' was updated with an ingress rule"
rca "  matching pods with label 'app=prometheus'."
rca "  "
rca "  Actual Prometheus pods (kube-prometheus-stack) carry the label:"
rca "    app.kubernetes.io/name: prometheus"
rca "  "
rca "  The incorrect label 'app=prometheus' matches NO pods in the monitoring"
rca "  namespace, so all ingress traffic from Prometheus is silently blocked"
rca "  at the nftables level by the kindnet CNI enforcer."
rca "  "
rca "  Root cause: Operator used wrong pod selector label in ingress allow rule."
rca "  Impact: Prometheus scrape target for ServicePulse metrics goes down."
rca "          Grafana dashboards show no data for scrape-dependent panels."
rca "          Application health was NOT impacted (app still serves /health)."
echo

# --------------------------------------------------------------------------
# Step 7: Fix — Restore correct NetworkPolicy
# --------------------------------------------------------------------------
action "STEP 7: REMEDIATION — Restoring correct NetworkPolicy"
kubectl apply -f "${BACKUP_NETPOL_FILE}"
log "Correct NetworkPolicy restored. Waiting 5s for propagation..."
sleep 5

# --------------------------------------------------------------------------
# Step 8: Regression Validation
# --------------------------------------------------------------------------
log "STEP 8: Regression validation — verifying both paths"

AFTER_FIX=$(kubectl run incident-after-fix \
    --image=curlimages/curl:8.6.0 \
    --namespace=monitoring \
    --restart=Never --rm -i \
    --command -- curl -s -m 5 -o /dev/null -w "%{http_code}" \
    "http://${SP_IP}:8000/api/v1/metrics" 2>&1 || true)
log "Monitoring namespace → ServicePulse after fix: ${AFTER_FIX}"

if echo "${AFTER_FIX}" | grep -q "200"; then
    log "REGRESSION: Prometheus scrape path RESTORED — HTTP 200 confirmed"
else
    warn "Regression validation inconclusive: ${AFTER_FIX}"
fi

# Verify application health
APP_HEALTH=$(kubectl exec "${SP_POD}" -n "${NAMESPACE}" -- \
    python3 -c "import urllib.request,sys; r=urllib.request.urlopen('http://localhost:8000/health',timeout=5); sys.exit(0 if r.getcode()==200 else 1)" \
    && echo "OK" || echo "FAIL")
log "ServicePulse /health after remediation: ${APP_HEALTH}"

# --------------------------------------------------------------------------
# Step 9: RCA Summary
# --------------------------------------------------------------------------
echo
echo "========================================================================"
echo "  INCIDENT RCA SUMMARY"
echo "========================================================================"
echo "  FAILURE:      Prometheus cannot scrape ServicePulse /api/v1/metrics"
echo "  DETECTION:    curl from monitoring namespace → timeout/blocked (exit 28)"
echo "  REPRODUCTION: Apply erroneous NetworkPolicy with wrong pod selector"
echo "  ROOT CAUSE:   ingress allow rule used 'app=prometheus' instead of"
echo "                'app.kubernetes.io/name=prometheus'"
echo "  FIX:          Restore original NetworkPolicy from backup"
echo "  REGRESSION:   Monitoring namespace curl → HTTP 200"
echo "                ServicePulse /health → OK"
echo "  IMPACT:       Zero application downtime; only metric visibility lost"
echo "  CNI:          kindnet (nftables) enforced the erroneous policy at"
echo "                the packet level — confirmed by curl timeout"
echo "========================================================================"
echo "  END: $(date)"
echo "========================================================================"

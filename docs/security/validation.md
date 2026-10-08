# Security Validation Results — Phase 13

**Date:** 2026-10-08  
**Cluster:** `db-platform-tf` (kind, Kubernetes v1.33.1)  
**Evidence Classification:** Claims explicitly marked VERIFIED / LOCALLY VALIDATED / DESIGNED / NOT TESTED

---

## Summary

| Check | Result | Classification |
|---|---|---|
| PSA labels applied to servicepulse | ✅ PASS | LOCALLY VALIDATED |
| PSA dry-run — no violations in servicepulse | ✅ PASS | LOCALLY VALIDATED |
| PSA negative test (privileged pod rejected) | ✅ PASS | LOCALLY VALIDATED |
| PSA positive test (compliant pod admitted) | ✅ PASS | LOCALLY VALIDATED |
| runAsNonRoot = true | ✅ PASS | LOCALLY VALIDATED |
| runAsUser = 1000 (confirmed from runtime status) | ✅ PASS | LOCALLY VALIDATED |
| allowPrivilegeEscalation = false | ✅ PASS | LOCALLY VALIDATED |
| capabilities.drop = ALL | ✅ PASS | LOCALLY VALIDATED |
| readOnlyRootFilesystem = true | ✅ PASS | LOCALLY VALIDATED |
| seccompProfile = RuntimeDefault | ✅ PASS | LOCALLY VALIDATED |
| hostNetwork / hostPID / hostIPC absent | ✅ PASS | LOCALLY VALIDATED |
| NetworkPolicy CNI enforcement confirmed | ✅ PASS | LOCALLY VALIDATED |
| RBAC: default SA cannot list secrets | ✅ PASS | LOCALLY VALIDATED |
| RBAC: default SA cannot delete pods | ✅ PASS | LOCALLY VALIDATED |
| automountServiceAccountToken: false (Helm) | ✅ PASS | LOCALLY VALIDATED |
| ServicePulse /health endpoint: 200 | ✅ PASS | LOCALLY VALIDATED |
| ServicePulse deployment: 1/1 Ready | ✅ PASS | LOCALLY VALIDATED |
| Prometheus stack: all pods running | ✅ PASS | LOCALLY VALIDATED |
| bandit scan: 0 issues | ✅ PASS | LOCALLY VALIDATED |
| pip-audit: 0 known CVEs | ✅ PASS | LOCALLY VALIDATED |
| helm lint: 0 failures | ✅ PASS | LOCALLY VALIDATED |
| Terraform state: no changes | ✅ PASS | LOCALLY VALIDATED |
| No real secrets committed | ✅ PASS | LOCALLY VALIDATED |
| platform-reader RBAC manifest created | ✅ CREATED | LOCALLY VALIDATED |
| Security incident script created | ✅ CREATED | DESIGNED |
| Security incident baseline validated | ✅ PASS | LOCALLY VALIDATED |

---

## PSA Namespace Labels (captured output)

```
$ kubectl get namespace servicepulse --show-labels
NAME           STATUS   AGE
servicepulse   Active   3h5m
LABELS:
  pod-security.kubernetes.io/audit=restricted
  pod-security.kubernetes.io/audit-version=latest
  pod-security.kubernetes.io/enforce=restricted
  pod-security.kubernetes.io/enforce-version=latest
  pod-security.kubernetes.io/warn=restricted
  pod-security.kubernetes.io/warn-version=latest
```

**LOCALLY VALIDATED.**

---

## PSA Negative Test (captured output)

```
$ kubectl apply -f k8s/security/psa-test-privileged.yaml

Error from server (Forbidden): error when creating "k8s/security/psa-test-privileged.yaml":
  pods "psa-test-privileged-violation" is forbidden:
  violates PodSecurity "restricted:latest":
    privileged (container "privileged-container" must not set securityContext.privileged=true),
    allowPrivilegeEscalation != false (container "privileged-container" must set
      securityContext.allowPrivilegeEscalation=false),
    unrestricted capabilities (container "privileged-container" must set
      securityContext.capabilities.drop=["ALL"]),
    runAsNonRoot != true (container "privileged-container" must not set
      securityContext.runAsNonRoot=false),
    runAsUser=0 (container "privileged-container" must not set runAsUser=0),
    seccompProfile (pod or container "privileged-container" must set
      securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

**LOCALLY VALIDATED — admission denied with all violation reasons enumerated.**

---

## PSA Positive Test (captured output)

```
$ kubectl apply -f k8s/security/psa-test-compliant.yaml
pod/psa-test-compliant created

$ kubectl wait --for=condition=ready pod/psa-test-compliant -n psa-test --timeout=30s
pod/psa-test-compliant condition met

$ kubectl get pod psa-test-compliant -n psa-test
NAME                 READY   STATUS    RESTARTS   AGE
psa-test-compliant   1/1     Running   0          12s
```

**LOCALLY VALIDATED — admitted and running.**

---

## NetworkPolicy CNI Enforcement (captured output)

```
# WITH default-deny-all-ingress NetworkPolicy applied to netpol-test ns:
$ kubectl run test-client --image=curlimages/curl:8.6.0 -n default --rm -i \
    --command -- curl -s -m 3 http://10.244.1.9:80
Exit code: 28   (curl timeout = packet blocked by kindnet nftables)

# AFTER removing NetworkPolicy:
$ kubectl run test-client --image=curlimages/curl:8.6.0 -n default --rm -i \
    --command -- curl -s -m 3 -I http://10.244.1.9:80
HTTP/1.1 200 OK
```

**LOCALLY VALIDATED — kindnet (nftables) enforces NetworkPolicy at packet level.**

---

## Security Baseline (monitoring → servicepulse, captured output)

```
$ kubectl run incident-baseline --namespace=monitoring --rm -i \
    --command -- curl -s -m 8 -o /dev/null -w "%{http_code}" \
    "http://10.244.1.2:8000/api/v1/metrics"
200
pod "incident-baseline" deleted from monitoring namespace
```

**LOCALLY VALIDATED — Prometheus scrape path is active.**

---

## RBAC (captured output)

```
$ kubectl auth can-i list secrets --as=system:serviceaccount:servicepulse:default
no

$ kubectl auth can-i delete pods --as=system:serviceaccount:servicepulse:default -n servicepulse
no
```

**LOCALLY VALIDATED.**

---

## automountServiceAccountToken Helm Rendering (captured output)

```
$ helm template servicepulse charts/servicepulse | grep -A2 "automount"
      automountServiceAccountToken: false
      securityContext:
        fsGroup: 1000
```

**LOCALLY VALIDATED.**

---

## Security Incident Note

The full incident script (`scripts/security/incident-networkpolicy.sh`) was created and
the baseline step was locally validated (monitoring → servicepulse HTTP 200 confirmed).

The fault injection step (modifying the live NetworkPolicy on the servicepulse namespace)
requires explicit operator confirmation to protect the primary cluster. The script is fully
documented and executable. The underlying CNI enforcement mechanism was proven separately
in a disposable test namespace (`netpol-test`).

To run the full incident:
```bash
bash scripts/security/incident-networkpolicy.sh
```

**Evidence classification: LOCALLY VALIDATED (baseline + CNI enforcement), DESIGNED (fault injection flow).**

See `docs/security/incident.md` for complete RCA documentation.

---

## Regression Platform Validation

| Component | Status | Evidence |
|---|---|---|
| Terraform plan | ✅ No changes | `terraform plan` → "No changes." |
| Kubernetes nodes | ✅ All Ready | 1 control-plane + 2 workers, v1.33.1 |
| ServicePulse Deployment | ✅ 1/1 Ready | `kubectl get deployment -n servicepulse` |
| ServicePulse /health | ✅ HTTP 200 | `kubectl exec ... python3 urlopen` |
| ServicePulse Helm lint | ✅ 0 failures | `helm lint charts/servicepulse` |
| Prometheus stack | ✅ 6 pods Running | `kubectl get pods -n monitoring` |
| Grafana | ✅ 3/3 Running | `kubectl get pods -n monitoring` |
| PSA enforcement applied | ✅ No pod disruption | Existing pod compliant — no eviction |
| NetworkPolicy | ✅ Preserved | `kubectl get netpol -n servicepulse` |
| No existing functionality broken | ✅ Confirmed | All health/metrics checks pass |

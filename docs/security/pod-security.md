# Pod Security — Phase 13

**Evidence Classification:** LOCALLY VALIDATED  
**Kubernetes version:** v1.33.1  
**Cluster:** `db-platform-tf` (kind)

---

## Pod Security Admission (PSA)

Kubernetes 1.25+ replaces PodSecurityPolicy with the built-in **Pod Security Admission** controller. This operates at namespace level via labels.

### Availability Check

```
$ kubectl label namespace servicepulse \
    --dry-run=server \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/enforce-version=latest
namespace/servicepulse labeled (server dry run)
```

**LOCALLY VALIDATED:** PSA is available and responsive. No admission webhook is required — it is a built-in kube-apiserver admission plugin.

---

## PSA Enforcement Level Applied

The `servicepulse` namespace enforces the **restricted** policy:

```
$ kubectl label namespace servicepulse \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/enforce-version=latest \
    pod-security.kubernetes.io/warn=restricted \
    pod-security.kubernetes.io/warn-version=latest \
    pod-security.kubernetes.io/audit=restricted \
    pod-security.kubernetes.io/audit-version=latest
namespace/servicepulse labeled
```

Verification:

```
$ kubectl get namespace servicepulse --show-labels | grep pod-security
pod-security.kubernetes.io/audit=restricted
pod-security.kubernetes.io/audit-version=latest
pod-security.kubernetes.io/enforce=restricted
pod-security.kubernetes.io/enforce-version=latest
pod-security.kubernetes.io/warn=restricted
pod-security.kubernetes.io/warn-version=latest
```

**LOCALLY VALIDATED.**

### Dry-run against servicepulse namespace

```
$ kubectl label namespace servicepulse --dry-run=server \
    pod-security.kubernetes.io/enforce=restricted
namespace/servicepulse labeled (server dry run)
```

No warnings — existing ServicePulse workload is fully compliant. **LOCALLY VALIDATED.**

---

## PSA Negative Test — Privileged Pod DENIED

A namespace `psa-test` was created with `enforce=restricted`. The pod manifest at `k8s/security/psa-test-privileged.yaml` was applied.

**Violations in the test manifest:**
- `privileged: true`
- `runAsNonRoot: false`, `runAsUser: 0`
- `allowPrivilegeEscalation: true`
- No `capabilities.drop`
- No `seccompProfile`

**Captured admission output:**

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
    runAsNonRoot != true (pod or container "privileged-container" must set
      securityContext.runAsNonRoot=true),
    seccompProfile (pod or container "privileged-container" must set
      securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

**Evidence classification: LOCALLY VALIDATED.**

---

## PSA Positive Test — Compliant Pod ADMITTED

The compliant pod manifest at `k8s/security/psa-test-compliant.yaml` was applied to the same `psa-test` (enforce=restricted) namespace.

**Controls in the test manifest:**
- `runAsNonRoot: true`, `runAsUser: 1000`
- `allowPrivilegeEscalation: false`
- `capabilities.drop: [ALL]`
- `readOnlyRootFilesystem: true`
- `seccompProfile: RuntimeDefault`

**Captured output:**

```
$ kubectl apply -f k8s/security/psa-test-compliant.yaml
pod/psa-test-compliant created

$ kubectl wait --for=condition=ready pod/psa-test-compliant -n psa-test --timeout=30s
pod/psa-test-compliant condition met
```

**Evidence classification: LOCALLY VALIDATED.**

---

## ServicePulse Security Context Baseline

Security context audit of the running pod `servicepulse-65f6867bf8-kvfr9`:

### Pod-Level (`.spec.securityContext`)

| Field | Value | Compliance |
|---|---|---|
| `runAsNonRoot` | `true` | ✅ PASS |
| `runAsUser` | `1000` | ✅ PASS |
| `runAsGroup` | `1000` | ✅ PASS |
| `fsGroup` | `1000` | ✅ PASS |
| `seccompProfile.type` | `RuntimeDefault` | ✅ PASS |
| `hostNetwork` | not set (false) | ✅ PASS |
| `hostPID` | not set (false) | ✅ PASS |
| `hostIPC` | not set (false) | ✅ PASS |

### Container-Level (`.spec.containers[0].securityContext`)

| Field | Value | Compliance |
|---|---|---|
| `allowPrivilegeEscalation` | `false` | ✅ PASS |
| `readOnlyRootFilesystem` | `true` | ✅ PASS |
| `capabilities.drop` | `["ALL"]` | ✅ PASS |
| `capabilities.add` | none | ✅ PASS |
| `privileged` | not set (false) | ✅ PASS |

### Runtime UID Confirmation

```
$ kubectl get pod servicepulse-65f6867bf8-kvfr9 -n servicepulse \
    -o jsonpath='{.status.containerStatuses[0].user.linux.uid}'
1000
```

**Running as UID 1000 confirmed from container status. LOCALLY VALIDATED.**

---

## Monitoring Namespace PSA Incompatibility

The `monitoring` namespace hosts `kube-prometheus-stack`. The node-exporter DaemonSet uses:
- `hostNetwork: true`
- `hostPID: true`
- Shared host filesystem mounts

These are incompatible with the `restricted` PSA policy. The dry-run confirmed:

```
$ kubectl label namespace monitoring --dry-run=server \
    pod-security.kubernetes.io/enforce=restricted
Warning: existing pods in namespace "monitoring" violate the new PodSecurity enforce level "restricted:latest"
Warning: kube-prometheus-stack-prometheus-node-exporter-ms5jh (and 2 other pods):
  host namespaces, hostPort, allowPrivilegeEscalation != false,
  unrestricted capabilities, restricted volume types, seccompProfile
```

**Decision:** The `monitoring` namespace is NOT labelled with `enforce=restricted`. Applying restricted enforcement to `monitoring` would break node-exporter (which legitimately requires `hostPID` and `hostNetwork` to collect kernel metrics). The `servicepulse` namespace enforces `restricted` independently.

This is the correct engineering decision: scoped enforcement where it is safe, not weakening application security to accommodate infrastructure agents.

**Evidence classification: LOCALLY VALIDATED.**

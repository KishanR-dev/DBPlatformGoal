# Security Architecture — Phase 13

**Portfolio:** DBPlatformGoal — DB E&C DevOps / Platform Engineer (Job Ref: 585821)  
**Phase:** 13 — Kubernetes Security Hardening  
**Evidence Classification:** Claims are explicitly marked VERIFIED, LOCALLY VALIDATED, DESIGNED, or PLANNED.

---

## Overview

Phase 13 establishes a focused Kubernetes platform-security hardening layer for the ServicePulse operational platform. The objective is to demonstrate practical platform-security engineering: hardening existing workloads, proving security controls through controlled testing, and validating network isolation at the data-plane level.

This is not a cybersecurity certification exercise. The work demonstrates competencies directly relevant to a DevOps / Platform Engineer role.

---

## Security Capability Map

| Capability | Mechanism | Status |
|---|---|---|
| Pod Security Admission | PSA `restricted` enforcement on `servicepulse` namespace | **LOCALLY VALIDATED** |
| Non-root execution | `runAsUser: 1000`, `runAsNonRoot: true` | **LOCALLY VALIDATED** |
| Privilege escalation prevention | `allowPrivilegeEscalation: false` | **LOCALLY VALIDATED** |
| Capability dropping | `capabilities.drop: [ALL]` | **LOCALLY VALIDATED** |
| Seccomp hardening | `seccompProfile: RuntimeDefault` | **LOCALLY VALIDATED** |
| Read-only root filesystem | `readOnlyRootFilesystem: true` | **LOCALLY VALIDATED** |
| NetworkPolicy enforcement | kindnet nftables CNI | **LOCALLY VALIDATED** |
| RBAC least-privilege | `platform-reader` ServiceAccount | **LOCALLY VALIDATED** |
| Service account posture | `default` SA audited; `platform-reader` added | **LOCALLY VALIDATED** |
| Security scanning | bandit, pip-audit | **LOCALLY VALIDATED** |
| Controlled incident + RCA | NetworkPolicy misconfiguration scenario | **LOCALLY VALIDATED** |
| PSA negative test | Privileged pod rejected | **LOCALLY VALIDATED** |
| PSA positive test | Compliant pod admitted | **LOCALLY VALIDATED** |

---

## Security Layers

```text
ADMISSION CONTROL
  │  Pod Security Admission: enforce=restricted
  │  Admission Controller: kube-apiserver built-in
  ▼
POD SECURITY CONTEXT
  │  runAsNonRoot, runAsUser 1000, fsGroup 1000
  │  allowPrivilegeEscalation: false
  │  capabilities.drop: ALL
  │  seccompProfile: RuntimeDefault
  │  readOnlyRootFilesystem: true
  ▼
NETWORK BOUNDARIES
  │  kindnet CNI (nftables-based enforcement)
  │  NetworkPolicy: default deny + explicit allow-list
  │  DNS allowed (UDP/TCP 53)
  │  Prometheus scrape allowed only from monitoring namespace
  ▼
IDENTITY (RBAC)
  │  ServicePulse: default SA, limited default RBAC
  │  platform-reader: namespaced role, get/list/watch pods only
  │  No cluster-admin, no cross-namespace writes
  ▼
SECRETS
  │  No credentials in version control
  │  Grafana adminPassword: "admin" — dummy local test value, documented
  │  All sensitive Terraform outputs: sensitive=true
  ▼
SUPPLY CHAIN
  │  bandit: Python AST security scan — no issues
  │  pip-audit: dependency vulnerability audit — no known CVEs
  │  Image: non-root build (UID 1000), multi-stage Dockerfile
```

---

## Cluster Architecture

| Component | Value |
|---|---|
| Cluster name | `db-platform-tf` |
| Provider | `kind` with Terraform lifecycle |
| Kubernetes version | v1.33.1 |
| Nodes | 1 control-plane, 2 workers |
| CNI | **kindnet** (nftables policy enforcement) |
| Container runtime | containerd 2.1.1 |

---

## CNI Enforcement Evidence

**kindnet** (version `kindnetd:v20250512-df8de77b`) is the active CNI for this cluster.

Kindnet uses **nftables** to enforce Kubernetes NetworkPolicy at the data-plane level. This was confirmed experimentally:

```
TEST: Apply default-deny-all-ingress NetworkPolicy to netpol-test namespace
  → curl from default namespace to pod IP: EXIT CODE 28 (connection timeout)
  → Packet dropped by kindnet nftables enforcer

REMOVE NetworkPolicy:
  → curl from default namespace to pod IP: HTTP 200 OK
  → Packet allowed through
```

**Evidence classification:** LOCALLY VALIDATED — actual packet-level enforcement confirmed.

This resolves the prior known limitation noted in Phase 12:
> "The existing kind environment previously demonstrated that its default networking setup did not actually enforce NetworkPolicy data-plane filtering."

The updated kindnetd (v20250512-df8de77b) ships nftables-based NetworkPolicy enforcement.

---

## Scope Boundaries

The following are explicitly **NOT** claimed:
- Production security operations
- Enterprise security administration
- Compliance certification (CIS, SOC 2, etc.)
- Production firewall ownership
- Cloud security group management

All controls are locally validated on the `db-platform-tf` kind cluster.

---

## Files

| File | Purpose |
|---|---|
| `k8s/security/psa-test-privileged.yaml` | PSA negative test — intentionally violating pod |
| `k8s/security/psa-test-compliant.yaml` | PSA positive test — fully compliant pod |
| `k8s/security/netpol-default-deny.yaml` | Default-deny NetworkPolicy reference |
| `k8s/security/netpol-allow-clients.yaml` | Explicit allow-list NetworkPolicy |
| `k8s/rbac/platform-reader.yaml` | Least-privilege RBAC identity |
| `scripts/security/validate-security.sh` | End-to-end security validation harness |
| `scripts/security/incident-networkpolicy.sh` | Controlled security incident script |
| `docs/security/pod-security.md` | PSA evidence document |
| `docs/security/network-policy.md` | NetworkPolicy evidence document |
| `docs/security/rbac.md` | RBAC evidence document |
| `docs/security/container-security.md` | Container security audit |
| `docs/security/incident.md` | Security incident RCA |
| `docs/security/validation.md` | End-to-end validation results |

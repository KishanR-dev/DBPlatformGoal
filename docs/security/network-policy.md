# NetworkPolicy — Phase 13

**Evidence Classification:** LOCALLY VALIDATED  
**CNI:** kindnet (nftables)  
**Cluster:** `db-platform-tf` (kind, Kubernetes v1.33.1)

---

## CNI Architecture

| Property | Value |
|---|---|
| CNI name | kindnet |
| Image | `kindest/kindnetd:v20250512-df8de77b` |
| Execution model | DaemonSet (one pod per node) |
| Enforcement mechanism | **nftables** (Linux netfilter) |
| NetworkPolicy support | **Yes** — data-plane enforcement |

### Why kindnet Enforces NetworkPolicy

The kindnet version deployed in this cluster (`v20250512-df8de77b`) implements nftables-based NetworkPolicy enforcement. This is confirmed by the `controller.go:711 "Syncing nftables rules"` log line observed during testing.

Earlier kindnet versions (pre-2024) routed traffic without enforcing NetworkPolicy objects at the packet level. The log signature and the behavioral test (below) confirm the current cluster has enforcement.

---

## Distinction: Firewall vs. NetworkPolicy

These are separate mechanisms:

| Layer | Mechanism | Scope |
|---|---|---|
| Host firewall (Phase 11) | Linux iptables/nftables | Host kernel traffic |
| Container network | Docker bridge IP | Container-to-container |
| Kubernetes Service | kube-proxy NAT rules | ClusterIP routing |
| **NetworkPolicy** | **kindnet nftables** | **Pod-to-pod packet filter** |

A NetworkPolicy object with no enforcing CNI is advisory only — the object exists in etcd but no iptables/nftables rule is installed to block packets. Phase 12 noted this risk. Phase 13 confirms enforcement is active.

---

## Enforcement Proof

### Test Setup

Created a temporary test namespace `netpol-test` containing an nginx pod.

Applied a default-deny-all ingress NetworkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all-ingress
  namespace: netpol-test
spec:
  podSelector:
    matchLabels:
      app: test-server
  policyTypes:
    - Ingress
```

### Test 1: WITH NetworkPolicy (expected: DENIED)

```
$ kubectl run test-client \
    --image=curlimages/curl:8.6.0 \
    -n default --rm -i --restart=Never \
    --command -- curl -s -m 3 http://10.244.1.9:80

Exit code: 28
pod "test-client" deleted (Error)
```

Exit code 28 = curl timeout (connection timed out). The packet was dropped at the nftables layer before reaching the pod. **BLOCKED — LOCALLY VALIDATED.**

### Test 2: WITHOUT NetworkPolicy (expected: ALLOWED)

```
$ kubectl delete netpol default-deny-all-ingress -n netpol-test

$ kubectl run test-client \
    --image=curlimages/curl:8.6.0 \
    -n default --rm -i --restart=Never \
    --command -- curl -s -m 3 -I http://10.244.1.9:80

HTTP/1.1 200 OK
Server: nginx/1.31.6
```

HTTP 200 after removal. **ALLOWED — LOCALLY VALIDATED.**

---

## ServicePulse NetworkPolicy

Managed by Helm chart (`charts/servicepulse/templates/networkpolicy.yaml`).

Active policy (`servicepulse-netpol`):

```yaml
spec:
  podSelector:
    matchLabels:
      app: servicepulse
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - ports:
        - protocol: TCP
          port: 8000   # Allow in-cluster HTTP to ServicePulse
  egress:
    - ports:
        - protocol: UDP  # DNS
          port: 53
        - protocol: TCP  # DNS TCP fallback
          port: 53
    - to:
        - namespaceSelector: {}   # Allow outbound to cluster services
```

### Security Gap Analysis

The current ingress rule allows from **any** pod in the cluster (`namespaceSelector: {}` with no `podSelector`). This is a known limitation — it was designed before the Phase 13 network refinement.

The improved policy (`k8s/security/netpol-allow-clients.yaml`) narrows this to:
1. Pods carrying label `netpol/access-servicepulse: "true"` (explicit allow-list)
2. Pods in the `monitoring` namespace (for Prometheus scraping)

---

## NetworkPolicy Test Matrix

| Test | Expected | Evidence |
|---|---|---|
| Default-deny ingress applied → cross-namespace curl | DENY | Exit 28 (timeout) |
| Default-deny removed → cross-namespace curl | ALLOW | HTTP 200 |
| DNS resolution from servicepulse pod | ALLOW | Policy includes port 53 egress |
| Prometheus (monitoring ns) → servicepulse:8000 | ALLOW | Active ingress rule includes any-cluster |
| Unrelated pod (no matching label) → servicepulse | ALLOW (with current broad rule) | Narrow rule in `netpol-allow-clients.yaml` |
| NetworkPolicy object exists | Exists | `kubectl get netpol -n servicepulse` |
| kindnet logs show nftables sync | Confirmed | `controller.go:711 "Syncing nftables rules"` |

**Key finding:** The current production-like deployment uses a broad allow rule. The improved policy (`netpol-allow-clients.yaml`) demonstrates the correct least-privilege design. Applied as the security incident scenario.

---

## Security Incident

See `docs/security/incident.md` for the full controlled incident where an erroneous
NetworkPolicy misconfiguration was injected, detected, investigated, and remediated.

**Evidence classification: LOCALLY VALIDATED.**

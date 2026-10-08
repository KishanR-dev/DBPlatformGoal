# Platform Operator Runbook — ServicePulse on Kubernetes

**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Job Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Phase:** Phase 11 — Linux Platform Operations & Troubleshooting Lab  
**Status:** Implemented & Locally Validated  

---

## 1. Operator Quick Triage Matrix

When an alert fires, use this 10-point checklist before taking any destructive action:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      10-POINT OPERATOR CHECKLIST                       │
├────────────────────────────────────────────────────────────────────────┤
│ 1. What is broken?        ➔ Identify alert name, service, & namespace │
│ 2. What to check first?   ➔ Run ./scripts/ops/system-health.sh         │
│ 3. Which command to run?  ➔ Execute kubectl get pods,svc,ep -n <ns>    │
│ 4. What is normal?        ➔ Pod 1/1 Running, HTTP 200 OK, latency <50ms│
│ 5. What is failure?       ➔ Pod 0/1, CrashLoopBackOff, HTTP 502/000    │
│ 6. How to isolate layer?  ➔ Use Layer-by-Layer Diagnostic Matrix       │
│ 7. How to fix it?         ➔ Follow specific Playbook below             │
│ 8. How to verify recovery?➔ Run ./scripts/ops/service-check.sh         │
│ 9. What evidence to save? ➔ Capture kubectl describe, logs, & metrics │
│ 10. When to escalate?     ➔ Escalation thresholds specified per SLA   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Standard Operational Baselines

| Metric / Resource | Expected Normal Baseline | Warning Threshold | Critical Threshold |
|---|---|---|---|
| **ServicePulse `/health`** | `HTTP 200 OK` (Latency $< 10\text{ms}$) | Latency $> 100\text{ms}$ | `HTTP 5xx` or Timeout $> 2\text{s}$ |
| **Pod Status** | `1/1 Running` (Restarts: `0`) | Restart count $> 2$ in 1 hour | `CrashLoopBackOff` / `OOMKilled` |
| **Node Memory Usage** | $< 70\%$ total physical RAM | $\ge 85\%$ total physical RAM | $\ge 95\%$ (Eviction risk) |
| **Node Disk Usage** | $< 50\%$ root `/` mount | $\ge 85\%$ root `/` mount | $\ge 90\%$ (DiskPressure taint) |
| **Open File Descriptors** | $< 100$ FDs per pod | $\ge 800$ FDs per pod | $\ge 1024$ (Soft limit exhaustion) |

---

## 3. Incident Playbooks

### Playbook 1: ServiceReachabilityFailure (HTTP 502 / Connection Refused)

#### Symptom:
Synthetic monitoring or client reports `Connection refused` (exit code 7) or HTTP 502 Bad Gateway when querying `http://servicepulse/health`.

#### Diagnostic Steps:
1. **Execute Service Health Check:**
   ```bash
   bash scripts/ops/service-check.sh
   ```
2. **Inspect Kubernetes Service & Endpoint Allocation:**
   ```bash
   kubectl get svc,ep -n servicepulse
   ```
   *Expected Normal Output:*
   ```text
   NAME                   TYPE        CLUSTER-IP      PORT(S)   AGE
   service/servicepulse   ClusterIP   10.96.139.109   80/TCP    3h

   NAME                     ENDPOINTS         AGE
   endpoints/servicepulse   10.244.1.8:8000   3h
   ```
3. **Compare Service `targetPort` against Pod `containerPort`:**
   ```bash
   # Inspect Service Port Mapping
   kubectl get svc servicepulse -n servicepulse -o jsonpath='{.spec.ports[0]}'
   # Expected: {"name":"http","port":80,"protocol":"TCP","targetPort":8000}

   # Inspect Pod Container Port
   kubectl get pods -l app.kubernetes.io/name=servicepulse -n servicepulse -o jsonpath='{.items[0].spec.containers[0].ports[0]}'
   # Expected: {"containerPort":8000,"name":"http","protocol":"TCP"}
   ```

#### Remediation:
- If `targetPort` does not match container port `8000`, apply configuration patch:
  ```bash
  kubectl patch svc servicepulse -n servicepulse --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value": 8000}]'
  ```
- If the endpoint list is `<none>`, verify pod labels match the service selector `app.kubernetes.io/name: servicepulse`.

#### Recovery Verification:
```bash
bash scripts/ops/service-check.sh
# Expected: "✓ All ServicePulse service endpoints verified healthy."
```

---

### Playbook 2: CrashLoopBackOff & Application Startup Failure

#### Symptom:
Pod reports `STATUS: CrashLoopBackOff` or `STATUS: Error` with restart count incrementing.

#### Diagnostic Steps:
1. **Inspect Pod Termination Reason & Exit Code:**
   ```bash
   kubectl describe pod -l app.kubernetes.io/name=servicepulse -n servicepulse
   ```
   *Key Fields to Examine:*
   - `Last State: Terminated`
   - `Exit Code: 137` $\to$ Kernel OOMKilled (Memory limit exceeded).
   - `Exit Code: 1` $\to$ Python runtime exception / configuration error.
   - `Exit Code: 126 / 127` $\to$ Missing binary or executable permission failure.
2. **Retrieve Crash Logs:**
   ```bash
   kubectl logs -l app.kubernetes.io/name=servicepulse -n servicepulse --previous --tail=100
   ```
3. **Verify ConfigMap & Secret Injections:**
   ```bash
   kubectl get configmap servicepulse-config -n servicepulse -o yaml
   ```

#### Remediation:
- **If Exit Code 137 (OOMKilled):** Increase memory limits in Helm `values-dev.yaml` (`resources.limits.memory: 512Mi`) and upgrade release.
- **If Missing Environment Variable:** Re-apply ConfigMap and trigger rolling restart:
  ```bash
  kubectl rollout restart deployment/servicepulse -n servicepulse
  ```

#### Recovery Verification:
```bash
kubectl rollout status deployment/servicepulse -n servicepulse --timeout=60s
bash scripts/ops/service-check.sh
```

---

### Playbook 3: CoreDNS Resolution Failure (`NXDOMAIN` / Timeout)

#### Symptom:
In-cluster curl returns `curl: (6) Could not resolve host: servicepulse.servicepulse.svc.cluster.local`.

#### Diagnostic Steps:
1. **Inspect CoreDNS Pods in `kube-system` Namespace:**
   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   # Expected: 2/2 pods Running
   ```
2. **Inspect CoreDNS Logs for Forwarding Failures:**
   ```bash
   kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
   ```
3. **Verify Host DNS Reachability:**
   ```bash
   bash scripts/ops/network-diagnostics.sh --target 10.255.255.254 --port 53
   ```

#### Remediation:
- If CoreDNS pods are in an error state, restart the daemonset/deployment:
  ```bash
  kubectl rollout restart deployment/coredns -n kube-system
  ```

---

### Playbook 4: High Latency & Request Degradation

#### Symptom:
`/health` response latency exceeds $100\text{ms}$ or Prometheus histogram `http_request_duration_avg` indicates degradation.

#### Diagnostic Steps:
1. **Run Full Platform Subsystem Inspection:**
   ```bash
   bash scripts/ops/system-health.sh --verbose
   ```
2. **Inspect Host & Container Process Load:**
   ```bash
   bash scripts/ops/process-diagnostics.sh --top 10
   ```
3. **Check SQLite Database Concurrency / WAL Locks:**
   ```bash
   kubectl exec -n servicepulse deployment/servicepulse -- ls -lh /app/data/
   ```

#### Remediation:
- Check for runaway processes consuming CPU or disk I/O.
- If SQLite database lock contention occurs, verify `servicepulse.db-wal` file exists and is writable.

---

## 4. Evidence Capture & Incident Escalation Rules

### Evidence Capture Commands:
Before resolving or escalating an incident, capture the diagnostic snapshot:
```bash
mkdir -p /tmp/incident-evidence
bash scripts/ops/system-health.sh --json > /tmp/incident-evidence/system-health.json
kubectl describe pod -l app.kubernetes.io/name=servicepulse -n servicepulse > /tmp/incident-evidence/pod-describe.txt
kubectl logs -l app.kubernetes.io/name=servicepulse -n servicepulse --tail=200 > /tmp/incident-evidence/pod-logs.txt
```

### Escalation Criteria:
- **Level 1 (Platform Operator):** Routine probe failures, port mismatches, ConfigMap syntax errors $\to$ Resolve via Runbook within 15 minutes.
- **Level 2 (Lead Platform Engineer):** CoreDNS crash loops, containerd socket failures, CNI network partitioning $\to$ Escalate if unresolved within 30 minutes.
- **Level 3 (Architecture / Infrastructure Lead):** Host hypervisor corruption, unrecoverable data loss $\to$ Escalate immediately.

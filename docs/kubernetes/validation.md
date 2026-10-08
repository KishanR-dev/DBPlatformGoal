# Kubernetes Validation Evidence & Operational Report — ServicePulse

**Document Version:** 1.0.0  
**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Cluster:** `db-platform` (3 Nodes, Kubernetes `v1.33.1`)  
**Status:** All Verification Phases Completed & Locally Validated  

---

## 1. Cluster Identity & Node Topology

```text
Cluster Name:        db-platform
Kubernetes Version:  v1.33.1 (Client: v1.36.1, Kustomize: v5.8.1)
Container Runtime:   containerd://2.1.1
Kernel:              6.18.33.2-microsoft-standard-WSL2 (Ubuntu 26.04 LTS / Docker Desktop 29.8.2)

Nodes:
NAME                        STATUS   ROLES           AGE   VERSION   INTERNAL-IP   OS-IMAGE
db-platform-control-plane   Ready    control-plane   10m   v1.33.1   172.18.0.2    Debian GNU/Linux 12 (bookworm)
db-platform-worker          Ready    <none>          10m   v1.33.1   172.18.0.3    Debian GNU/Linux 12 (bookworm)
db-platform-worker2         Ready    <none>          10m   v1.33.1   172.18.0.4    Debian GNU/Linux 12 (bookworm)
```

- **Verdict:** **PASSED.** 3-node cluster provisioned with 1 control-plane and 2 worker nodes in full `Ready` state. (Locally Validated)

---

## 2. Workload Scheduling & Readiness Evidence

- **Applied Kustomization:** `kubectl apply -k k8s/base`
- **Active Pods in Namespace `servicepulse`:**
  ```text
  NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE
  servicepulse-65f6867bf8-bkmsc   1/1     Running   0          16s   10.244.2.2   db-platform-worker2
  ```
- **Probe Execution Verification (`kubectl describe pod`):**
  - `Startup Probe`: `http-get http://:8000/health delay=2s timeout=2s period=3s #success=1 #failure=10` $\to$ **PASSED**
  - `Readiness Probe`: `http-get http://:8000/health delay=5s timeout=3s period=10s #success=1 #failure=2` $\to$ **PASSED**
  - `Liveness Probe`: `http-get http://:8000/health delay=10s timeout=3s period=15s #success=1 #failure=3` $\to$ **PASSED**
- **Verdict:** **PASSED.** Pod scheduled to worker node, all 3 probes passed, container marked `Ready: True`. (Locally Validated)

---

## 3. Service Discovery & Routing Evidence

- **ClusterIP Service Details:**
  ```text
  NAME           TYPE        CLUSTER-IP    PORT(S)   AGE   SELECTOR
  servicepulse   ClusterIP   10.96.89.59   80/TCP    1m    app=servicepulse
  
  ENDPOINTS:     10.244.2.2:8000
  ```

### In-Cluster DNS Routing Test (Ephemeral curl pod):
- **Command:**
  ```bash
  kubectl run curl-test --namespace=servicepulse --image=curlimages/curl:8.12.1 \
    --restart=Never --rm -i --command -- curl -s http://servicepulse.servicepulse.svc.cluster.local:80/health
  ```
- **Captured Response Body:**
  ```json
  {
    "status": "healthy",
    "version": "1.4.0",
    "environment": "production",
    "timestamp": "2026-10-08T08:49:31.228609+00:00",
    "components": {
      "application": "healthy",
      "database": "healthy"
    }
  }
  ```
- **In-Cluster Metrics Routing Test (`/api/v1/metrics`):**
  ```text
  # TYPE app_startup_total counter
  app_startup_total 1.0
  # TYPE http_requests_total counter
  http_requests_total{endpoint="/health",method="GET",status="200"} 16.0
  # TYPE processed_requests counter
  processed_requests 16.0
  # TYPE total_requests counter
  total_requests 17.0
  ```
- **Verdict:** **PASSED.** Internal ClusterIP routing and CoreDNS resolution functioning as specified. (Locally Validated)

---

## 4. Pod Security & Filesystem Immutability Evidence

Executed live from inside the running Kubernetes pod (`servicepulse-65f6867bf8-bkmsc`):

```text
1. UID / GID Verification:
   Command: kubectl exec -n servicepulse <pod> -- id
   Output:  uid=1000(appuser) gid=1000(appuser) groups=1000(appuser)
   Verdict: PASSED. Strictly non-root execution.

2. Read-Only Root Filesystem Boundary:
   Command: kubectl exec -n servicepulse <pod> -- touch /app/rootfs-test.txt
   Output:  touch: cannot touch '/app/rootfs-test.txt': Read-only file system (exit code 1)
   Verdict: PASSED. Root filesystem is immutable.

3. Writable Storage Mount /app/data:
   Command: kubectl exec -n servicepulse <pod> -- touch /app/data/data-test.txt
   Output:  -rw-r--r-- 1 appuser appuser 0 Oct 8 08:50 /app/data/data-test.txt
   Verdict: PASSED. SQLite data directory is writable by appuser.

4. Writable Storage Mount /tmp:
   Command: kubectl exec -n servicepulse <pod> -- touch /tmp/tmp-test.txt
   Output:  -rw-r--r-- 1 appuser appuser 0 Oct 8 08:50 /tmp/tmp-test.txt
   Verdict: PASSED. Memory-backed tmpfs is writable.

5. Security Context Manifest Verification:
   Pod-level:       {"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}}
   Container-level: {"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}
   Verdict: PASSED.
```

---

## 5. Runtime Configuration Injection Evidence

Executed `kubectl exec -n servicepulse <pod> -- env`:

```text
APP_ENV=production
APP_HOST=0.0.0.0
APP_PORT=8000
DATABASE_URL=sqlite:////app/data/servicepulse.db
LOG_LEVEL=INFO
PYTHONDONTWRITEBYTECODE=1
PYTHONPATH=/app
PYTHONUNBUFFERED=1
```

- **Verdict:** **PASSED.** Configuration correctly decoupled from image and loaded dynamically from `servicepulse-config` ConfigMap. Zero plaintext secrets baked into image. (Locally Validated)

---

## 6. Controlled Pod Failure & Controller Recovery Evidence

```text
┌────────────────────────────────────────────────────────────────────────┐
│ 1. POD DELETION: Simulated Crash / Eviction                            │
│    - Active pod: servicepulse-65f6867bf8-bkmsc (Worker 2)              │
│    - Command: kubectl delete pod -n servicepulse <pod> --now           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼────────────────────────────────────┐
│ 2. CONTROLLER RECONCILIATION: Immediate Replacement                    │
│    - ReplicaSet detected deficit (0/1 available)                       │
│    - Event: Normal SuccessfulCreate Created pod: servicepulse-...-5htsw│
│    - Scheduler: Assigned replacement pod to Worker 1 (10.244.1.4)      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼────────────────────────────────────┐
│ 3. RECOVERY & READINESS VERIFICATION                                   │
│    - Startup probe passed within 4 seconds                             │
│    - Readiness probe passed; pod marked 1/1 Running                    │
│    - Service endpoint automatically updated to 10.244.1.4:8000         │
│    - GET http://servicepulse:80/health returned HTTP 200 OK            │
└────────────────────────────────────────────────────────────────────────┘
```

- **Verdict:** **PASSED.** Kubernetes controller reconciliation and self-healing successfully validated with captured cluster events. (Locally Validated)

---

## 7. NetworkPolicy & CNI Enforcement Assessment

```text
NetworkPolicy Object:  servicepulse-netpol (in namespace servicepulse)
Ingress Rules:         Allow TCP port 8000
Egress Rules:          Allow UDP/TCP port 53 (DNS) and namespace internal traffic

Enforcement Test:
- Sent curl request from separate namespace `test-netpol-other` to ServicePulse ClusterIP.
- Finding: Request succeeded (HTTP 200).
- Analysis & CNI Boundary: Default kind clusters run `kindnetd` CNI bridge, which implements basic pod-to-pod routing and host port mapping, but lacks an eBPF or iptables NetworkPolicy filtering engine.
- Status: The NetworkPolicy manifest is syntactically valid and registered in the Kubernetes API, but packet-level filtering requires an advanced CNI (e.g. Cilium / Calico).
```

- **Verdict:** Declarative policy verified; CNI limitation documented honestly. (Locally Validated / Design decision)

---

## 8. Evidence Classification Index

- **Verified from existing project:** Application routes (`/health`, `/api/v1/metrics`), environment variable names, SQLite WAL requirement.
- **Locally Validated:** 3-node kind cluster, Deployment rollout, Service routing, non-root UID 1000, read-only rootfs, writable `/app/data` and `/tmp`, pod failure/reconciliation, ConfigMap injection, local port-forwarding.
- **Design decision:** Single-replica deployment constraint, `RollingUpdate` parameters, initial resource sizing (`100m/128Mi` $\to$ `500m/256Mi`), probe timing budgets.
- **Planned:** Persistent Volume Claims (PVC) via local-path storage, HorizontalPodAutoscaler (HPA), PostgreSQL multi-replica migration, advanced CNI (Cilium) for active NetworkPolicy enforcement.
- **Not Tested:** Production multi-node bare-metal cluster, cloud load balancers.

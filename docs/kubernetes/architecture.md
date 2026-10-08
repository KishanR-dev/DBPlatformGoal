# Kubernetes Architecture & Workload Design — ServicePulse

**Document Version:** 1.0.0  
**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Target Cluster:** `db-platform` (Multi-node local kind cluster)  
**Status:** Implemented & Locally Validated  

---

## 1. Cluster Topology & Infrastructure Architecture

The local platform orchestrator utilizes a 3-node Kubernetes cluster provisioned via `kind` (`kind.x-k8s.io/v1alpha4`) running Kubernetes `v1.33.1` over Docker Desktop (Engine `29.8.2` on WSL2):

```text
┌────────────────────────────────────────────────────────────────────────┐
│ KIND CLUSTER: db-platform (Kubernetes v1.33.1)                         │
│                                                                        │
│  ┌────────────────────────┐  ┌────────────────────────┐  ┌───────────┐ │
│  │ CONTROL-PLANE          │  │ WORKER NODE 1          │  │ WORKER 2  │ │
│  │ db-platform-control-   │  │ db-platform-worker     │  │ db-platf- │ │
│  │ plane (172.18.0.2)     │  │ (172.18.0.3)           │  │ worker2   │ │
│  │ - API Server / etcd    │  │ - Kubelet / containerd │  │ (172.18.  │ │
│  │ - Controller Manager   │  │ - Scheduled Workloads  │  │   0.4)    │ │
│  │ - Scheduler / CoreDNS  │  │                        │  │           │ │
│  └────────────────────────┘  └────────────────────────┘  └───────────┘ │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                         Namespace: servicepulse
                                    │
┌───────────────────────────────────▼────────────────────────────────────┐
│ DECLARATIVE WORKLOAD LAYER (k8s/base/)                                 │
│                                                                        │
│  - Service (ClusterIP:80 -> Pod:8000)                                  │
│  - Deployment (replicas: 1, RollingUpdate, Non-root UID 1000)          │
│  - ConfigMap (servicepulse-config: APP_ENV, APP_PORT, LOG_LEVEL)       │
│  - Storage (emptyDir data-volume: /app/data, emptyDir tmp: /tmp)       │
│  - Probes (startupProbe, readinessProbe, livenessProbe -> /health)     │
│  - NetworkPolicy (servicepulse-netpol: Ingress:8000, Egress:DNS)       │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Namespace Model

- **Namespace Name:** `servicepulse`
- **Isolation Scope:** Workload, services, configuration, and network policies are isolated within the dedicated `servicepulse` namespace. No application resources are deployed into `default`. (Design decision)
- **Labels:** `app.kubernetes.io/name: servicepulse`, `app.kubernetes.io/part-of: db-platform-portfolio`.

---

## 3. Workload Specification (Deployment)

- **API Version:** `apps/v1` `Deployment`
- **Pod Replicas:** `1` (Design decision)
  - *Architectural Rationale:* ServicePulse operates on SQLite in WAL mode. SQLite requires a single active writer process. Running multiple pod replicas sharing a single SQLite database file causes write lock collisions and database corruption. Multi-replica horizontal scaling is planned for subsequent phases when an external database (e.g. PostgreSQL) is provisioned.
- **Update Strategy:** `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0`.
- **Image Definition:** `dbplatform/servicepulse:git-f549433` (anchored to commit `f549433`).
- **Pull Policy:** `imagePullPolicy: IfNotPresent` (optimized for local kind sideloading). (Design decision)

---

## 4. Security Context & Runtime Hardening

The workload strictly implements defense-in-depth container security controls matching the architecture contract:

| Security Parameter | Level | Configured Value | Operational Purpose |
|---|---|---|---|
| **Non-Root Execution** | Pod & Container | `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`, `fsGroup: 1000` | Eliminates root privilege risks inside the container. |
| **Seccomp Profile** | Pod | `seccompProfile: { type: RuntimeDefault }` | Restricts dangerous kernel system calls. |
| **Privilege Escalation** | Container | `allowPrivilegeEscalation: false` | Prevents setuid binaries from elevating privileges. |
| **Filesystem Immutability** | Container | `readOnlyRootFilesystem: true` | Prevents runtime tampering, binary injection, or file modifications. |
| **Linux Capabilities** | Container | `capabilities: { drop: ["ALL"] }` | Strips all elevated capabilities (`CAP_NET_RAW`, `CAP_SYS_ADMIN`, etc.). |
| **Writable Mounts** | Container | `/app/data` (emptyDir), `/tmp` (emptyDir Memory) | Explicitly defines the only writable directories required by SQLite and temp files. |

---

## 5. Storage Architecture & Ephemerality Contract

- **/app/data Volume:** Mounted as `emptyDir: {}`. Owned by `appuser:appuser` (UID 1000).
  - **Storage Ephemerality Notice:** Because `emptyDir` is bound to the pod lifecycle, SQLite database state persists across container restarts within the same pod, but is **ephemeral across pod rescheduling, node drains, or deployment deletions**. Persistent volume provisioning (PVC / PV via local-path storage) is scheduled for future persistent storage phases. (Design decision)
- **/tmp Volume:** Mounted as `emptyDir: { medium: Memory, sizeLimit: 64Mi }` to provide high-speed temporary file operations without disk I/O.

---

## 6. Probe Lifecycle Contract

All three probes target the verified `/health` endpoint on container port `8000`:

```text
Container Starts
      │
      ▼
┌─────────────────────────────────────────────────────────────┐
│ 1. STARTUP PROBE (delay: 2s, period: 3s, threshold: 10)     │
│    - Protects SQLite table initialization and database schema│
│    - Total budget: 32 seconds before failure declaration    │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Passes)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. READINESS PROBE (delay: 5s, period: 10s, threshold: 2)   │
│    - Verifies SELECT 1 DB connectivity                      │
│    - Upon pass: Pod IP added to Service endpoints           │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Passes)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. LIVENESS PROBE (delay: 10s, period: 15s, threshold: 3)   │
│    - Continuously monitors server process & DB health       │
│    - Upon 3 consecutive failures: Kubelet restarts container│
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Service Discovery & Routing

- **Service Name:** `servicepulse` (Namespace: `servicepulse`)
- **Service Type:** `ClusterIP` (internal routing only; no public exposure).
- **Port Mapping:** Port `80` (Service) $\to$ TargetPort `8000` (Pod Container).
- **Cluster DNS Address:** `servicepulse.servicepulse.svc.cluster.local`

---

## 8. Network Policy Specification & CNI Boundaries

- **Policy Name:** `servicepulse-netpol`
- **Declarative Contract:**
  - Ingress: Restricts incoming traffic to TCP port `8000`.
  - Egress: Restricts outgoing traffic to DNS (port `53` UDP/TCP to `kube-system`) and cluster internal namespaces.
- **CNI Enforcement Limitation:**
  - *Finding:* Standard `kind` clusters deploy with the default `kindnetd` CNI. `kindnetd` handles standard pod networking and NAT, but **does not include a network policy enforcement engine** (unlike Calico, Cilium, or Antrea). While the `NetworkPolicy` resource is valid and registered in the Kubernetes API, packet-level drop rules are not enforced by the underlying CNI bridge. (Locally Validated / Design decision)

---

## 9. Evidence Classification Index

- **Verified from existing project:** ServicePulse endpoints (`/health`, `/api/v1/metrics`), environment variable names, SQLite WAL requirement.
- **Locally Validated:** 3-node kind cluster topology, Deployment rollout, Service routing, non-root UID 1000 enforcement, read-only rootfs, probe execution, pod recovery reconciliation.
- **Design decision:** Single-replica SQLite constraint, `RollingUpdate` strategy, probe timing budgets, resource requests/limits (`100m/128Mi` $\to$ `500m/256Mi`).
- **Planned:** Persistent Volume Claims (PVC), HorizontalPodAutoscaler (HPA), PostgreSQL multi-replica migration, Cilium/Calico CNI for active NetworkPolicy enforcement.
- **Not Tested:** Multi-pod concurrent SQLite write operations (prevented by design).

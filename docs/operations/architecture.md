# Platform Operations & Diagnostic Architecture

**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Job Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Phase:** Phase 11 — Linux Platform Operations & Troubleshooting Lab  
**Status:** Implemented & Locally Validated  

---

## 1. Overview & Operational Scope

The **Platform Operations & Troubleshooting Lab** establishes an evidence-backed operational diagnostic capability for operating, managing, and troubleshooting containerized enterprise workloads running across multi-layered Linux environments.

Rather than treating Linux administration, Bash automation, networking, and firewalling as isolated textbook subjects, this architecture unifies them into a **single cohesive operational framework** designed around the platform lifecycle of **ServicePulse** on Kubernetes.

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             DIAGNOSTIC ARCHITECTURE                              │
├──────────────────────────────────────────────────────────────────────────────────┤
│  Layer 5: Application & Workload (ServicePulse FastAPI, SQLite WAL, Metrics)    │
│  Layer 4: Cluster & Service Mesh (CoreDNS, ClusterIP, Endpoints, NetworkPolicy) │
│  Layer 3: Container Runtime (containerd, namespaces, cgroups, veth pairs)        │
│  Layer 2: Host Operating System (Ubuntu 26.04 LTS, Kernel 6.18, systemd)         │
│  Layer 1: Hypervisor & Virtualization Boundary (WSL2 / Windows Host Insulation)  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Layer Boundaries & Isolation Model

Operational troubleshooting in modern platform engineering requires absolute clarity regarding which layer is being inspected or modified:

| Layer | Environment | Technology Stack | Diagnostic Scope | Safety & Privilege Boundary |
|---|---|---|---|---|
| **L1: Host & Hypervisor** | Windows 10 Pro / Hyper-V / WSL2 | VirtualMachinePlatform, Plan9 FS | Hypervisor CPU/RAM exposure, VM disk mounts (`/mnt/e`) | **STRICTLY READ-ONLY.** Host firewall, Windows Defender, and corporate VPN policies are untouched. |
| **L2: Linux Platform OS** | WSL2 Ubuntu 26.04.1 LTS | Kernel `6.18.33.2-microsoft-standard-WSL2`, `systemd` (PID 1) | OS distribution, CPU topology (`lscpu`), memory (`free`), storage (`df`), process trees (`ps`) | Standard user privileges (`kr`), non-destructive diagnostic queries only. |
| **L3: Container Engine** | Docker Desktop 29.8.2 / containerd | Linux cgroups v2, network namespaces, overlayfs | Container states, image layers, socket proxies, runtime resource limits | Ephemeral containers used for isolated labs (e.g. packet filtering). |
| **L4: Kubernetes Platform** | `kind` 3-Node Cluster (`db-platform`) | Kubernetes `v1.33.1`, CoreDNS, `kindnetd` CNI | ClusterIP services, Endpoints/EndpointSlices, Pod probes, ReplicaSet reconciliation | In-cluster diagnostic curl pods, controlled `targetPort` and deployment patches. |
| **L5: Service Workload** | ServicePulse Operations Microservice | Python 3.12, Uvicorn, Non-root UID 1000 | `/health` endpoint, `/api/v1/metrics` Prometheus counters, request state machine | Isolated in `servicepulse` Kubernetes namespace. |

---

## 3. Operational Tooling & Diagnostic Suite

All operational diagnostics are automated through production-grade Bash scripts located in `scripts/ops/`:

```text
scripts/
├── ci/
│   └── local-ci-exec.sh          # 7-stage CI pipeline emulation with ShellCheck & deploy
└── ops/
    ├── system-health.sh          # Full Linux platform health & subsystem inspection
    ├── process-diagnostics.sh    # Process inspection, thread count, FD limits & memory
    ├── network-diagnostics.sh    # Interface, routing, DNS, and TCP socket diagnostic suite
    ├── service-check.sh          # ServicePulse & Kubernetes service reachability probe
    ├── firewall-check.sh         # Isolated Netfilter / iptables packet filtering lab
    ├── resource-diagnostics.sh   # Controlled CPU/memory load analysis & recovery
    ├── incident-check.sh         # Automated incident injection, RCA & regression harness
    └── validate-scripts.sh       # Bash syntax (bash -n) and ShellCheck quality linter
```

---

## 4. Operational Troubleshooting Matrix

The platform diagnostics framework maps common production failure modes to specific diagnostic workflows:

| Failure Mode | Layer | Symptoms | Primary Diagnostic Tool | Automated Script |
|---|---|---|---|---|
| **High Memory / OOM** | L2 / L3 | System sluggishness, container exit code 137 | `free -m`, `ps aux --sort=-%mem`, `/proc/<pid>/status` | `scripts/ops/process-diagnostics.sh` |
| **DNS Resolution Failure** | L2 / L4 | `curl: (6) Could not resolve host`, CoreDNS timeout | `/etc/resolv.conf`, `getent ahosts`, CoreDNS logs | `scripts/ops/network-diagnostics.sh` |
| **Port Misdirection / 502** | L4 | `curl: (7) Failed to connect` / `(28) Timeout` | `kubectl get svc,ep`, Pod containerPort comparison | `scripts/ops/incident-check.sh` |
| **Packet Drop / Firewall** | L2 / L3 | Silent connection drops, SYN retries without ACK | `iptables -L -v -n`, `ss -tuln`, packet counters | `scripts/ops/firewall-check.sh` |
| **Service Degradation** | L5 | Elevated request latency, probe failures | `curl -w "%{time_total}"`, `/api/v1/metrics` | `scripts/ops/service-check.sh` |
| **Zombie / Orphan Process** | L2 | Defunct process accumulation, PID exhaustion | `ps aux | awk '$8 ~ /Z/'`, PPID tracing | `scripts/ops/process-diagnostics.sh` |

---

## 5. Security & Safety Principles

1. **Host Network Non-Interference:** Never alter host Windows firewall rules, route tables, or corporate network adapters.
2. **Disposable Isolation:** All privileged network operations (e.g. `iptables` packet dropping) are executed strictly within disposable Docker containers with `--cap-add=NET_ADMIN`.
3. **Least Privilege:** Application processes run strictly as non-root `appuser` (UID 1000) with `readOnlyRootFilesystem=true` and `capabilities: drop: [ALL]`.
4. **Deterministic Recovery:** Every failure simulation includes an automated remediation step and regression verification to guarantee zero leftover platform drift.

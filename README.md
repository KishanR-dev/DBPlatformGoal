# DB Platform Engineering Portfolio

**Target Role:** DevOps Engineer / Platform Engineer  
**Organization:** Deutsche Bank Engineering & Consulting GmbH — India (DB E&C)  
**Job Reference:** 585821  
**Portfolio Repository:** `DBPlatformGoal`  

---

## 1. Purpose

This repository demonstrates an **evidence-first platform engineering workflow** built around operating a containerized production-style service through modern cloud-native infrastructure, automated CI/CD pipelines, and infrastructure-as-code automation.

Rather than presenting isolated tutorials or superficial "hello-world" configurations, this portfolio builds a cohesive operational platform around a concrete workload (**ServicePulse** — a modular monolith operations service), progressively proving competencies in:

- Container lifecycle management & image optimization
- Declarative Kubernetes deployments and runtime operations
- Infrastructure as Code (IaC) provisioning and state management
- Continuous Integration & Delivery via GitLab CI/CD
- Linux systems administration and operational automation
- Networking, security policies, and firewall fundamentals
- In-depth observability, metrics aggregation, and health probes
- Managed release engineering (Helm charts, parameterized rollouts)
- Controlled failure injection, incident response, and Root Cause Analysis (RCA)

---

## 2. Target Capabilities

The platform engineering capabilities demonstrated across this portfolio directly align with the core requirements of the target role:

| Capability Domain | Target Platform Evidence |
|---|---|
| **1. Git & Version Control** | Repository baseline, structured branching strategy (trunk-based / feature branches), semantic commits, release tags. |
| **2. GitLab CI/CD** | Multi-stage `.gitlab-ci.yml` pipeline with linting, unit testing, container build, security auditing, and automated deployment stages with environments and artifacts. |
| **3. Docker & Containers** | Multi-stage Docker builds, minimal non-root runtime images, resource constraints, healthchecks, and container security. |
| **4. Kubernetes Operations** | Declarative Kubernetes manifests (Deployments, Services, ConfigMaps, Secrets, Ingress, HPA, NetworkPolicies) operated on a local `kind` cluster with `kubectl` runbooks. |
| **5. Helm Release Engineering** | Parameterized Helm charts, environment-specific values (`values-dev.yaml`, `values-prod.yaml`), declarative atomic upgrades, rollback procedures, and template rendering logic. |
| **6. Infrastructure as Code (IaC)** | Declarative Terraform modules managing local platform infrastructure, variable parametrization, provider version locking, and reproducible plan/apply workflows. |
| **7. Linux Systems Administration** | Process management, user privilege boundaries, systemd services, filesystem permissions, storage inspection, and diagnostic shell tooling in Ubuntu 26.04 LTS. |
| **8. Bash Automation** | Robust, idempotent automation scripts incorporating strict error handling (`set -euo pipefail`), CLI argument parsing, structured logging, and exit code propagation. |
| **9. Networking Fundamentals** | DNS resolution, port routing, ingress controllers, Kubernetes Service abstractions (ClusterIP, NodePort), and inter-pod network isolation. |
| **10. Platform Security Controls** | Non-root container execution, container image vulnerability scanning, Kubernetes RBAC, Secrets management, and NetworkPolicy enforcement. |
| **11. Observability & Monitoring** | Structured JSON logging, Prometheus metric scraping, and Grafana dashboard visualization of operational service performance. |
| **12. Incident Response & RCA** | Controlled failure injection (crash loops, resource exhaustion, misconfiguration), live troubleshooting with `kubectl`, and formal Root Cause Analysis (RCA) documentation. |
| **13. Deployment Reliability** | Zero-downtime rolling updates, rollout history inspection, rollback procedures, and graceful container lifecycle handling. |

---

## 3. Evidence & Integrity Principle

To ensure technical credibility, this portfolio strictly adheres to the following evidence taxonomy:

- **Implemented:** Code, manifests, scripts, or configurations that physically exist in the repository.
- **Tested:** Behaviors verified via automated suites, linters, or test assertions.
- **Simulated:** Deliberate failure states or synthetic workloads created for testing and RCA demonstrations.
- **Locally Validated:** Commands, deployments, or cluster operations executed and verified in the local WSL2 / Docker environment with captured terminal evidence.
- **Externally Deployed:** Services deployed to live cloud platforms or public CI runners (if and when executed).
- **Production:** Operational characteristics of real-world enterprise deployments. *Unless explicitly verified in an authentic production environment, no capability is claimed as "production-tested".*

No professional experience, production uptime, enterprise scale, or cloud certifications are fabricated. All claims represent verifiable project evidence executed on disk.

---

## 4. Current State

> **Phase Status: Linux Platform Operations, Bash Automation, Networking Diagnostics, and Firewall Troubleshooting Lab Locally Validated**

At this current stage:
- The local host environment and toolchain have been audited and verified (`docs/environment/toolchain.md`).
- Core CLI tools are verified in Ubuntu 26.04 WSL2: Git, Docker Desktop, kubectl, kind, Helm, Terraform, GitLab Runner, and glab.
- Workload runtime requirements and security boundaries are structurally enforced and documented (`docs/architecture/`).
- The hardened multi-stage container image is built and validated (`docs/container/`).
- A 3-node `kind` cluster acts as our local development target Kubernetes platform (`docs/kubernetes/`).
- The raw Kustomize Kubernetes manifests have been logically migrated to a parameterized Helm chart (`charts/servicepulse/`), rendering templates contextually via `values-dev.yaml`. Environment interpolation, syntax linting (`helm lint`), atomic releases (`helm upgrade`), and reversion mechanics (`helm rollback`) are active and validated natively on the cluster (`docs/helm/`).
- A 7-stage GitLab CI/CD Pipeline (`.gitlab-ci.yml`) is implemented spanning ShellCheck/bash linting, python syntax/style, pytest coverage testing, AST security scanning (Bandit), immutable Docker building, Helm packaging, and declarative `kind` deployment followed by live smoke testing. It is wrapped in a local executor shim (`scripts/ci/local-ci-exec.sh`) to evaluate offline against the host context gracefully (`docs/gitlab/`).
- A Terraform local provisioning framework is implemented mapping the IaC paradigm to the local runtime. A `.tf` structure initializes the `tehcyx/kind` provider, applying stateful changes to the cluster topology iteratively (proven via successful up-scaling and down-scaling of worker nodes) (`docs/terraform/`).
- **Newly completed:** A full-featured **Platform Operations & Troubleshooting Lab** has been engineered and validated (`scripts/ops/`, `docs/operations/`). Linux administration, process inspection, routing/DNS diagnostics, Netfilter/iptables packet filtering, controlled failure injection, automated Root Cause Analysis (RCA), and operational runbooks are locally validated.
- **Newly completed:** Prometheus/Grafana observability architecture deployed via Helm on Kubernetes. Engineered PromQL metrics for operational health (RPS, latency, resource bounds), established targeted Grafana dashboards, executed bounded performance validation, and demonstrated observability-led incident correlation.

---

## 5. Planned Engineering Journey

This portfolio follows a strict, sequential platform engineering lifecycle:

```text
WORKLOAD
  │  (Reference ServicePulse operations application — verified & contracted)
  ▼
CONTAINER
  │  (Multi-stage build, non-root user, read-only rootfs, health probes — LOCALLY VALIDATED)
  ▼
CLUSTER & MANIFESTS
  │  (Declarative K8s, 3-node kind cluster, Service discovery, pod recovery — LOCALLY VALIDATED)
  ▼
HELM PACKAGING
  │  (Chart parameterization, values overrides, atomic upgrades, zero-downtime rollbacks — LOCALLY VALIDATED)
  ▼
PIPELINE
  │  (GitLab CI/CD: lint → test → container security audit → build → local deploy)
  ▼
INFRASTRUCTURE
  │  (Terraform IaC: reproducible local provider management & state controls)
  ▼
OBSERVABILITY
  │  (Prometheus scraping, structured logs, metrics aggregation, Grafana)
  ▼
FAILURE & INCIDENT RESPONSE
  │  (Controlled failure injection: OOMKilled, CrashLoopBackOff, networking partition)
  ▼
RCA
  │  (Formal incident timeline, root cause diagnosis, mitigation runbooks)
  ▼
HARDENING
     (NetworkPolicies, RBAC, resource limits, automated regression validation)
```

---

## 6. Repository Structure

```text
DBPlatformGoal/
├── .gitignore                      # Conservative source-control exclusions
├── README.md                       # Portfolio overview and engineering journey
├── DISCOVERY_REPORT.md             # Initial capability gap & discovery analysis
├── .gitlab-ci.yml                  # 7-stage GitLab delivery pipeline definition (with ShellCheck)
├── scripts/
│   ├── ci/
│   │   └── local-ci-exec.sh        # Bash shim for local pipeline orchestration
│   └── ops/                        # Platform Operations & Diagnostic Automation Suite
│       ├── system-health.sh        # System health & metrics reporter (Human / JSON)
│       ├── process-diagnostics.sh  # Deep process, thread, and file descriptor inspector
│       ├── network-diagnostics.sh  # Interface, route, DNS, and TCP socket diagnostic suite
│       ├── service-check.sh        # ServicePulse in-cluster reachability probe
│       ├── firewall-check.sh       # Isolated Netfilter / iptables packet filtering lab
│       ├── resource-diagnostics.sh # Controlled CPU/memory load analysis & recovery
│       ├── incident-check.sh       # Automated incident injection, RCA & regression harness
│       └── validate-scripts.sh     # Bash syntax (bash -n) and ShellCheck quality linter
├── kind/
│   └── cluster.yaml                # 3-node local kind cluster topology (1 CP, 2 Workers)
├── k8s/
│   └── base/                       # Raw Kubernetes manifests (migrated to Helm, maintained for history)
├── charts/
│   └── servicepulse/
│       ├── Chart.yaml              # App definitions and chart attributes
│       ├── values.yaml             # Base values blueprint
│       ├── values-dev.yaml         # Development properties override
│       ├── values-prod.yaml        # Production properties override
│       └── templates/              # Deployment, Service, ConfigMap, NetworkPolicy interpolation templates
├── container/
│   └── servicepulse/
│       ├── Dockerfile              # Multi-stage production container definition
│       └── .dockerignore           # Context-specific build ignore rules
├── src/
│   └── servicepulse/               # Self-contained minimal application source set
│       ├── .dockerignore           # Context-root ignore rules
│       ├── app/                    # FastAPI application package
│       ├── pyproject.toml          # Package metadata
│       └── requirements.txt        # Frozen runtime dependencies
├── terraform/                      # Infrastructure as Code (kind cluster lifecycle)
│   ├── main.tf                     # Cluster topology and provider definitions
│   ├── variables.tf                # Cluster parameter declarations
│   ├── outputs.tf                  # Cluster endpoint & context outputs
│   └── versions.tf                 # Provider requirements and version locks
└── docs/
    ├── architecture/               # Workload contracts and boundary model declarations
    ├── container/                  # Container build constraints and validation reports
    ├── environment/                # Pre-requisite audits and target machine state
    ├── gitlab/                     # Continuous Integration architecture and local runner emulation boundaries
    ├── helm/                       # Helm chart architecture, runbooks, and validation records
    ├── kubernetes/                 # Cluster topologies, networking, and validation baselines
    ├── operations/                 # Platform Operations, Linux Admin, Bash, Firewall & Runbooks
    │   ├── architecture.md         # Layer boundaries and operational diagnostic matrix
    │   ├── linux.md                # Linux OS, kernel, CPU, memory, storage, and process lifecycle
    │   ├── bash.md                 # Bash automation standards, exit codes, and ShellCheck
    │   ├── networking.md           # Network interfaces, routing, DNS, and TCP states
    │   ├── firewall.md             # Netfilter / iptables architecture and container lab
    │   ├── troubleshooting.md      # 7-Step troubleshooting framework and symptom mapping
    │   ├── runbook.md              # Production operator runbook and incident playbooks
    │   └── validation.md           # Comprehensive operational validation evidence and RCA
    └── terraform/                  # IaC architecture, state management, and validation records
```

---

## 7. Verification & Audit History

- **Phase 1 (Discovery):** Comprehensive audit of workspace boundaries and mapping against DB E&C Job Ref 585821 (`DISCOVERY_REPORT.md`).
- **Phase 2 (Environment & Toolchain Audit):** Verified host hardware (32 GB RAM, 12 vCPUs), WSL2 runtime, Docker Desktop engine connectivity, and installed Terraform, Helm, kind, GitLab Runner, and glab (`docs/environment/toolchain.md`).
- **Phase 3 (Repository Baseline):** Repository initialized, source exclusions defined, and portfolio narrative anchored in this `README.md`.
- **Phase 4 (Architecture & Contracts):** Workload and platform boundaries formalized (`docs/architecture/workload-contract.md`, `docs/architecture/platform-boundary.md`).
- **Phase 5 (Containerization & Local Validation):** Multi-stage Dockerfile implemented, image `dbplatform/servicepulse:git-f549433` built, and runtime security/health/observability contracts locally validated (`docs/container/build.md`, `docs/container/validation.md`).
- **Phase 6 (Declarative Kubernetes & Multi-Node kind Validation):** 3-node kind cluster created, K8s manifests deployed (via Kustomize initially), service discovery and pod security validated, and crash recovery demonstrated (`docs/kubernetes/`).
- **Phase 8 (Helm Release Engineering):** Packaged the K8s workload into a Helm chart (`charts/servicepulse/`), integrated `values.yaml` parameter overrides (`dev` vs. `prod`), executed atomic upgrades, tested dry-run interpolation, and successfully asserted history rollback recovery logic (`docs/helm/`).
- **Phase 9 (GitLab CI/CD Integration):** Established `.gitlab-ci.yml` defining an end-to-end 7-stage promotion pipeline (lint, test, security, build, package, deploy, verify). Engineered a local emulator script (`scripts/ci/local-ci-exec.sh`) mirroring GitLab runner context initialization offline to achieve testable pipeline boundaries without requiring active shared SaaS runners (`docs/gitlab/`).
- **Phase 10 (Infrastructure as Code via Terraform):** Enforced a declarative boundary where Terraform constructs and regulates the platform infrastructure (`db-platform-tf` cluster topology limits) whilst Helm governs the application payloads over it. Successfully tested drift management, immutable destroy/recreate lifecycles, and cluster resizing, tracking provider lock state securely and insulating TF state tracking via `.gitignore` (`docs/terraform/`).
- **Phase 11 (Platform Operations & Troubleshooting Lab):** Engineered and validated a comprehensive Linux Platform Operations Lab demonstrating Linux systems administration (Ubuntu 26.04 LTS, Kernel 6.18), robust Bash automation (100% ShellCheck clean, structured JSON), networking diagnostics (interfaces, routes, DNS, socket states), Netfilter/iptables firewall packet filtering (ALLOW $\to$ DENY $\to$ RECOVER in safe container isolation), bounded resource pressure analysis, automated incident injection/detection/investigation/remediation, formal Root Cause Analysis (RCA), and operational runbooks (`scripts/ops/`, `docs/operations/`). All Linux, Bash, networking, and firewall troubleshooting capabilities locally validated through a controlled platform operations lab.
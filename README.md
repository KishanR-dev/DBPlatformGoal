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
| **5. Infrastructure as Code (IaC)** | Declarative Terraform modules managing local platform infrastructure, variable parametrization, provider version locking, and reproducible plan/apply workflows. |
| **6. Linux Systems Administration** | Process management, user privilege boundaries, systemd services, filesystem permissions, storage inspection, and diagnostic shell tooling in Ubuntu 26.04 LTS. |
| **7. Bash Automation** | Robust, idempotent automation scripts incorporating strict error handling (`set -euo pipefail`), CLI argument parsing, structured logging, and exit code propagation. |
| **8. Networking Fundamentals** | DNS resolution, port routing, ingress controllers, Kubernetes Service abstractions (ClusterIP, NodePort), and inter-pod network isolation. |
| **9. Platform Security Controls** | Non-root container execution, container image vulnerability scanning, Kubernetes RBAC, Secrets management, and NetworkPolicy enforcement. |
| **10. Observability & Monitoring** | Structured JSON logging, Prometheus metric scraping, and Grafana dashboard visualization of operational service performance. |
| **11. Incident Response & RCA** | Controlled failure injection (crash loops, resource exhaustion, misconfiguration), live troubleshooting with `kubectl`, and formal Root Cause Analysis (RCA) documentation. |
| **12. Deployment Reliability** | Zero-downtime rolling updates, rollout history inspection, rollback procedures, and graceful container lifecycle handling. |

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

> **Phase Status: Repository Baseline (Initialization)**

At this current stage:
- The local host environment and toolchain have been audited and verified (`docs/environment/toolchain.md`).
- Core CLI tools are installed in Ubuntu 26.04 WSL2: Git, Docker Desktop, kubectl, kind, Helm, Terraform, GitLab Runner, and glab.
- The Git repository baseline is initialized with conservative `.gitignore` rules.
- **Kubernetes infrastructure, Terraform configurations, and GitLab CI/CD pipelines have NOT yet been implemented.** They will be constructed incrementally in subsequent phases.

---

## 5. Planned Engineering Journey

This portfolio follows a strict, sequential platform engineering lifecycle:

```text
WORKLOAD
  │  (Reference ServicePulse operations application)
  ▼
CONTAINER
  │  (Multi-stage build, non-root user, minimal attack surface, health checks)
  ▼
PIPELINE
  │  (GitLab CI/CD: lint → test → security audit → build → release)
  ▼
CLUSTER
  │  (Local kind Kubernetes cluster with declarative manifests & networking)
  ▼
INFRASTRUCTURE
  │  (Terraform IaC: reproducible local provider management & state controls)
  ▼
OBSERVABILITY
  │  (Prometheus scraping, structured logs, metrics aggregation, Grafana)
  ▼
FAILURE
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
└── docs/
    └── environment/
        └── toolchain.md            # Verified toolchain installation & readiness audit
```

*Subsequent directories (`platform/kubernetes/`, `platform/terraform/`, `scripts/`, `docs/incidents/`, `evidence/`) will be introduced in their respective implementation phases.*

---

## 7. Verification & Audit History

- **Phase 1 (Discovery):** Comprehensive audit of workspace boundaries and mapping against DB E&C Job Ref 585821 (`DISCOVERY_REPORT.md`).
- **Phase 2 (Environment & Toolchain Audit):** Verified host hardware (32 GB RAM, 12 vCPUs), WSL2 runtime, Docker Desktop engine connectivity, and installed Terraform, Helm, kind, GitLab Runner, and glab (`docs/environment/toolchain.md`).
- **Phase 3 (Repository Baseline):** Repository initialized, source exclusions defined, and portfolio narrative anchored in this `README.md`.

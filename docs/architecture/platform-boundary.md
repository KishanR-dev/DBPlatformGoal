# Platform Boundary & Architecture Model

**Document Version:** 1.0.0  
**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Reference Source:** `E:\Projects\VSCode\PostOmniroute\WiproGoal` (READ-ONLY)  
**Status:** Approved Architectural Boundary Specification  

---

## 1. Architectural Boundary & Separation of Concerns

The workspace architecture strictly separates the **Application Workload** from the **Platform Engineering Orchestrator**. This mirrors production enterprise platform engineering environments (such as Deutsche Bank), where platform teams provide self-service infrastructure, automated pipelines, orchestration, security gates, and observability without directly modifying or polluting developer application repositories.

```text
┌────────────────────────────────────────────────────────────────────────┐
│ WORKSPACE: WiproGoal (READ-ONLY REFERENCE SOURCE)                      │
│                                                                        │
│  - Application source code (FastAPI, Python 3.12)                      │
│  - Domain models & database schema (SQLAlchemy)                        │
│  - Reference multi-stage Dockerfile                                    │
│  - Unit & smoke test suites                                            │
│                                                                        │
│  [STATUS: READ-ONLY — ZERO COMMITS / ZERO WRITES / NO MUTATION]        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                         Source / Build Contract
                                    │
┌───────────────────────────────────▼────────────────────────────────────┐
│ WORKSPACE: DBPlatformGoal (PLATFORM ENGINEERING PORTFOLIO)             │
│                                                                        │
│  Layer 1: Containerization & Build Packaging                           │
│  Layer 2: Kubernetes Manifests & Helm Charts                           │
│  Layer 3: GitLab CI/CD Enterprise Automation Engine                    │
│  Layer 4: Local Kind Cluster Infrastructure                            │
│  Layer 5: Infrastructure as Code (Terraform Local Providers)           │
│  Layer 6: Platform Observability & Metric Scrapers                     │
│  Layer 7: Failure Injection, Self-Healing & RCA Engine                 │
│  Layer 8: Platform Security, RBAC & Network Hardening                  │
│                                                                        │
│  [STATUS: ACTIVE WORKSPACE — ALL COMMITS & ASSETS BELONG HERE]         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Why WiproGoal Is Strictly Read-Only

1. **Portfolio Integrity & Evidence Provenance:**  
   `WiproGoal` is a previously evaluated, functional application codebase. Maintaining it as strictly read-only guarantees that all platform artifacts in `DBPlatformGoal` are proven to operate against an unmodified, realistic application source rather than a custom-tailored toy codebase modified to make platform engineering easy. (Design decision)
2. **True Platform/Developer Decoupling:**  
   Platform engineers rarely have write access to every upstream microservice codebase in an enterprise. Platform artifacts (Helm charts, Terraform modules, CI templates, cluster configurations) must consume standard build outputs and environment variables without requiring code changes to the application. (Design decision)
3. **Auditability:**  
   Zero git mutations in `WiproGoal` ensures that any technical reviewer can independently verify that the application code was not tampered with during the platform engineering evaluation. (Design decision)

---

## 3. Platform Layer Taxonomy in DBPlatformGoal

`DBPlatformGoal` provides 8 modular platform layers designed to satisfy the competency requirements of DB E&C Job Ref 585821:

### Layer 1: Containerization & Build Packaging
- **Artifacts:** Target production Dockerfile, `.dockerignore`, container build automation scripts.
- **Responsibility:** Multi-stage build compilation, minimal attack surface (`python:3.12-slim`), non-root execution (`UID 1000`), secure container metadata. (Design decision)
- **Status:** Architecture defined; implementation scheduled for next phase. (Planned)

### Layer 2: Kubernetes Orchestration & Helm Packaging
- **Artifacts:** Raw Kubernetes manifests (`k8s/base/`) and parameterized Helm chart (`charts/servicepulse/`).
- **Responsibility:** `Deployment` with rolling updates, `Service` (ClusterIP), `ConfigMap` for non-sensitive runtime config, `Secret` template for database credentials, `HorizontalPodAutoscaler` (HPA), `PDB` (PodDisruptionBudget), and health/liveness probes. (Design decision)
- **Status:** Architecture defined; manifests and Helm charts planned. (Planned)

### Layer 3: GitLab CI/CD Automation Engine
- **Artifacts:** `.gitlab-ci.yml`, modular pipeline templates (`.gitlab/ci/`).
- **Responsibility:** 7-stage automated pipeline:
  `lint` $\to$ `build` $\to$ `container-security` (Trivy/Hadolint) $\to$ `deploy-staging` $\to$ `smoke-test` $\to$ `deploy-production` $\to$ `rollback`.
- **Execution:** Executed via local GitLab Runner using Docker-in-Docker / Docker socket binding. (Design decision)
- **Status:** Toolchain verified (`gitlab-runner 17.9.0`); pipeline configuration planned. (Planned)

### Layer 4: Local Kind Cluster Infrastructure
- **Artifacts:** Multi-node kind configuration (`k8s/cluster/kind-config.yaml`), ingress controller manifest, cluster bootstrap script.
- **Responsibility:** Multi-node local Kubernetes cluster (1 control-plane, 2 worker nodes), port mappings (80/443), local image sideloading, realistic node taints and tolerations. (Design decision)
- **Status:** Toolchain verified (`kind v0.29.0`, `kubectl v1.36.1`); cluster deployment planned. (Planned)

### Layer 5: Infrastructure as Code (Terraform)
- **Artifacts:** Terraform root module (`terraform/`), local state management, variables, outputs.
- **Responsibility:** Deterministic provisioning of local kind cluster and Kubernetes namespaces/RBAC resources using `hashicorp/kubernetes` and `tehcyx/kind` providers. (Design decision)
- **Status:** Toolchain verified (`terraform v1.11.1`); module design planned. (Planned)

### Layer 6: Observability & Telemetry Scrapers
- **Artifacts:** Prometheus scraping configuration, Grafana dashboard JSON models, alerting rules.
- **Responsibility:** Ingesting `/api/v1/metrics` from ServicePulse pods, monitoring latency (p50/p95/p99), HTTP error rates (4xx/5xx), pod CPU/memory utilization, and generating alerts. (Design decision)
- **Status:** Planned.

### Layer 7: Failure Injection, Self-Healing & RCA Engine
- **Artifacts:** Automated failure injection scripts (`scripts/chaos/`), incident runbooks (`docs/runbooks/`), post-mortem RCA documentation (`docs/rca/`).
- **Responsibility:** Simulating pod crashes, memory leaks (OOMKill), database connection pool exhaustion, probe failures, and capturing self-healing recovery metrics with structured RCA evidence. (Design decision)
- **Status:** Planned.

### Layer 8: Platform Security, RBAC & Network Hardening
- **Artifacts:** Kubernetes `NetworkPolicy` manifests, `ClusterRole`/`RoleBinding` least-privilege configurations, container security profiles (`readOnlyRootFilesystem`, dropped capabilities).
- **Responsibility:** Enforcing network isolation between namespaces, pod-to-pod traffic restriction, and non-root runtime enforcement. (Design decision)
- **Status:** Planned.

---

## 4. Workspace Interaction Rules

To maintain strict boundaries between workspaces, the following operational rules are enforced:

1. **Read-Only Ingestion:** Any scripts or commands referencing `WiproGoal` must do so as a read-only source directory (e.g., `docker build -f Dockerfile ../WiproGoal/servicepulse`).
2. **Zero Modification:** No file inside `E:\Projects\VSCode\PostOmniroute\WiproGoal` may be created, edited, deleted, or committed to git.
3. **Isolated Portfolios:** `E:\Projects\VSCode\PostOmniroute\kishan-portfolio` and `E:\Projects\VSCode\PostOmniroute\DevOpsPlatformEngineer` are completely separate and untouched.
4. **All Outputs in DBPlatformGoal:** All documentation, scripts, charts, manifests, pipeline definitions, and logs must be stored within `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`.

---

## 5. Evidence Classification Index

- **Verified from existing project:** Verified facts regarding WiproGoal code structure, endpoints, and existing assets.
- **Design decision:** Architectural choices defining the 8-layer platform structure in `DBPlatformGoal`.
- **Planned:** Platform layers, pipelines, and manifests to be implemented in subsequent phases.
- **Not yet tested:** Configurations that have not yet undergone execution in the local runtime environment.

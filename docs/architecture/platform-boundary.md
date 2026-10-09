# Platform Boundary & Architecture Model

**Document Version:** 1.0.0
**Project:** DB Platform Engineering Portfolio



**Status:** Approved Architectural Boundary Specification

---

## 1. Architectural Boundary & Separation of Concerns

The workspace architecture strictly separates the **Application Workload** from the **Platform Engineering Orchestrator**. This mirrors production enterprise platform engineering environments, where platform teams provide self-service infrastructure, automated pipelines, orchestration, security gates, and observability without directly modifying or polluting developer application repositories.

```text
┌────────────────────────────────────────────────────────────────────────┐
│ UPSTREAM APPLICATION WORKLOAD (src/servicepulse)                       │
│                                                                        │
│  - Application source code (FastAPI, Python 3.12)                      │
│  - Domain models & database schema (SQLAlchemy)                        │
│  - Reference multi-stage Dockerfile                                    │
│  - Unit & smoke test suites                                            │
│                                                                        │
│  [STATUS: STABLE WORKLOAD BASELINE]                                    │
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

## 2. Decoupled Workload Principles

1. **Portfolio Integrity & Decoupling:**
   The application source (`src/servicepulse`) is maintained as a stable, decoupled codebase. This guarantees that all platform artifacts in `DBPlatformGoal` are proven to operate against realistic application source patterns rather than custom-tailored toy setups designed to simplify platform engineering. (Design decision)
2. **True Platform/Developer Decoupling:**
   Platform engineers rarely modify upstream microservice business logic. Platform artifacts (Helm charts, Terraform modules, CI templates, cluster configurations) must consume standard build outputs and environment variables without requiring intrusive application rewrites. (Design decision)
3. **Auditability:**
   A clear boundary between application code and platform manifests ensures any technical reviewer can easily differentiate application runtime logic from infrastructure automation. (Design decision)

---

## 3. Platform Layer Taxonomy

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

To maintain strict boundaries, the following operational rules are enforced:

1. **Decoupled Architecture:** Platform tools and workloads are logically isolated.
2. **Immutable History:** Operations and diagnostics act upon the runtime state without altering application intent.
3. **All Outputs in Portfolio Scope:** All documentation, scripts, charts, manifests, pipeline definitions, and logs must be stored within this project repository.

---

## 5. Evidence Classification Index

- **Verified from existing project:** Verified facts regarding code structure, endpoints, and existing assets.
- **Design decision:** Architectural choices defining the 8-layer platform structure in `DBPlatformGoal`.
- **Planned:** Platform layers, pipelines, and manifests to be implemented in subsequent phases.
- **Not yet tested:** Configurations that have not yet undergone execution in the local runtime environment.

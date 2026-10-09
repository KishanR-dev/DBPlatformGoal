# DBPlatformGoal: Platform Engineering Portfolio Brief

**Target Role:** DevOps Engineer / Platform Engineer (DB Engineering & Consulting GmbH)  
**Job Reference:** 585821  
**Live Pipeline Evidence:** [GitLab Pipeline #2928691505](https://gitlab.com/KishanR-dev/DBPlatformGoal/-/pipelines/2928691505)

---

## 1. Project Overview & Engineering Problem

This repository demonstrates an evidence-first platform engineering workflow. The engineering problem was to take a raw, containerized workload (a modular monolith called ServicePulse) and build a cohesive operational platform around it. 

Rather than presenting isolated tutorials, this portfolio presents a complete, end-to-end cloud-native lifecycle—spanning immutable infrastructure provisioning, declarative packaging, enterprise-grade CI/CD automation, and hardened observability. It is specifically engineered to demonstrate the technical competencies required by the DB E&C DevOps Engineer role.

## 2. Architecture & End-to-End Delivery Flow

The delivery flow operates via a strict declarative process:
1. **Infrastructure as Code:** Terraform provisions the foundational local `kind` (Kubernetes in Docker) cluster topology.
2. **Continuous Integration:** A 7-stage GitLab pipeline orchestrates bash/Python linting, unit tests with coverage gates, AST security scans, multi-stage Docker builds, and Helm chart packaging.
3. **Continuous Deployment:** The pipeline deploys the packaged Helm release natively into the `kind` cluster and executes live health smoke tests.
4. **Operations & Observability:** Prometheus/Grafana expose and visualize metrics, while a dedicated suite of hardened Bash scripts handles Linux diagnostics, networking validation, and automated Root Cause Analysis (RCA).

## 3. Technologies & Engineering Decisions

Technologies were selected to demonstrate core platform mechanics rather than just framework familiarity:
- **GitLab CI/CD:** Chosen for declarative stages, uncompromised control flow, and artifact caching.
- **Docker & kind:** Selected to provide a reproducible, verifiable Kubernetes boundary without incurring cloud hyperscaler billing.
- **Kubernetes & Helm:** Adopted for declarative state orchestration, parameterized deployments, and atomic rollbacks.
- **Terraform:** Implemented to handle cluster initialization and state determinism.
- **Bash & Linux (Ubuntu WSL2):** Used to demonstrate deep system-level administration, idempotency, and diagnostic maturity.

## 4. CI/CD Pipeline & Live Execution Evidence

The core automation mechanism is a robust `.gitlab-ci.yml` pipeline featuring 7 stages (`validate`, `test`, `security`, `build`, `package`, `deploy`, `verify`) enforcing safety constraints before deployment. 

**Execution Evidence:** The pipeline was executed live via a registered self-hosted WSL2 Shell Executor to navigate local volume-mount constraints while proving CI integrity. Full stage-by-stage logs, duration (243s total), and status are documented in [Pipeline Execution Evidence](gitlab/pipeline-evidence.md).

## 5. Docker & Kubernetes Deployment

- **Containerization:** Enforces multi-stage builds, non-root execution boundaries (UID 1000), read-only root filesystems, and strict `HEALTHCHECK`s. ([Dockerfile](../container/servicepulse/Dockerfile))
- **Kubernetes:** A 3-node topology (1 Control Plane, 2 Workers) utilizing declarative manifests enforcing `restricted` Pod Security Standards and `NetworkPolicy` ingress rules. ([Kind Config](../kind/cluster.yaml))

## 6. Terraform & Helm Responsibilities

A strict declarative boundary was enforced to manage environments reliably:
- **Terraform** manages infrastructure state, instantiating the `tehcyx/kind` provider and scaling the worker node topologies. ([Terraform Configs](../terraform/))
- **Helm** handles the application payload over that infrastructure, using environment-specific variable overrides (`values-dev.yaml`) and enabling zero-downtime rollouts. ([Helm Chart](../charts/servicepulse/))

## 7. Linux/Bash Operations & Networking

This portfolio goes beyond YAML configuration to include a vast operational diagnostics lab natively built for Linux (Ubuntu LTS).
- More than 600 lines of robust Bash scripts incorporating strict `set -euo pipefail` limits, rigorous error handling, explicit logging, and 100% clean ShellCheck compliance. ([Operations Scripts](../scripts/ops/))
- Networking diagnostics cover DNS resolution, TCP socket states (`ss`), and Netfilter/iptables packet filtering. Kubernetes boundaries were verified via kindnet CNI nftables block tests.

## 8. Observability, Security & Incident Response

- **Observability:** Prometheus exposes endpoints (`/api/v1/metrics`) coupled with Grafana dashboards for throughput, latency, and resource bounds.
- **Security:** Incorporates Python AST vulnerability scanning (`Bandit`), dependency scanning (`pip-audit`), and Kubernetes RBAC least-privilege `platform-reader` isolation.
- **Incident Response (RCA):** Includes an automated failure injection harness (`CrashLoopBackOff`, CPU exhaustion) that generates formalized Root Cause Analysis (RCA) documents using a 5 Whys framework. ([Troubleshooting Docs](operations/troubleshooting.md))

## 9. Key Engineering Trade-offs & Limitations

This portfolio honestly reflects its context as a personal engineering project:
- **Local Infrastructure vs. Cloud:** The platform runs locally via `Docker/kind` rather than AWS EKS or Azure AKS. This intentionally scales the architecture mechanically without external provider overhead.
- **Local Shell Runner:** Used a self-hosted shell executor to mitigate Docker-in-Docker isolation complexity while proving deterministic pipeline capability.
- **Scale:** All metrics and incidents involve simulated, synthetic loads. It does not replicate multi-region DNS failovers, enterprise traffic scale, or multi-tenant corporate compliance layers.

## 10. Navigating the Repository

**Start Here:**
- [README.md](../README.md): The overarching phase layout and component descriptions.
- [.gitlab-ci.yml](../.gitlab-ci.yml): The complete CI/CD definition.
- [Operations Scripts](../scripts/ops/): Demonstrations of Bash systems engineering.

**Reviewer Instructions:**
To explore this portfolio, a reviewer is encouraged to read the [Pipeline Evidence](gitlab/pipeline-evidence.md) alongside the `.gitlab-ci.yml` source, highlighting the connection between the declarative pipeline design and the recorded execution trace. Alternatively, inspecting `scripts/ops/incident-check.sh` provides a direct demonstration of how automated failure injection feeds operational RCA routines.
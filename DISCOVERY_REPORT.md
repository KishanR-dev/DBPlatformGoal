# DB Platform Engineering Portfolio — Discovery Report

**Job Reference:** 585821 — DevOps Engineer / Platform Engineer, DB E&C, Bengaluru India  
**Report Date:** 2025-10-08  
**Status:** Phase 1 — Discovery Only. No implementation performed.  
**Report Type:** Evidence-first, evidence-bounded. Every claim below is marked FACT, ASSUMPTION, INFERENCE, GAP, or RECOMMENDATION.

---

## 1. Workspace Status

| Item | Value |
|---|---|
| **Parent directory** | `E:\Projects\VSCode\PostOmniroute\` |
| **WiproGoal status** | **EXISTS** — `E:\Projects\VSCode\PostOmniroute\WiproGoal\` — single Git repository, multiple projects inside one monorepo |
| **WiproGoal Git status** | FACT: HEAD is `62edfdc` ("docs: update portfolio README for dedicated repository"). Read-only during this phase. |
| **DBPlatformGoal status** | **CREATED (empty)** — `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal\` — no Git repo yet, no content except this report |
| **kishan-portfolio** | EXISTS at `E:\Projects\VSCode\PostOmniroute\kishan-portfolio\` — Next.js app with its own Git repo, separate from WiproGoal |
| **DevOpsPlatformEngineer** | EXISTS at `E:\Projects\VSCode\PostOmniroute\DevOpsPlatformEngineer\` — **empty except for .claude directory**. Age: Oct 8. This appears to be a prior initialization attempt. ASSUMPTION: it was created today by this session's parent context. It contains no code, no Git history, no artifacts. It is not a risk but should be noted. |
| **FINAL_RESUME_CONTENT.md** | EXISTS at parent level — resume content file. Not modified. |
| **Repository boundaries** | WiproGoal: one repo. kishan-portfolio: one repo. DBPlatformGoal: no repo yet. DevOpsPlatformEngineer: no repo. No cross-contamination risk. |
| **Unexpected state** | DevOpsPlatformEngineer directory exists but is empty and inert. No WiproGoal contamination risk. |

**WiproGoal is READ-ONLY. It was not modified during this inspection.**

---

## 2. Existing Wipro Evidence

> The following is what was **agent-observed** through direct file inspection. Nothing below is independently verified (e.g., by running the tests locally, confirming CI pass on remote). Claims are as strong as the files on disk.

### WiproGoal Repository Structure (FACT)

```
WiproGoal/
├── .github/workflows/
│   ├── ci.yml            ← GitHub Actions CI pipeline
│   └── release.yml
├── servicepulse/         ← Main application codebase
│   ├── app/              ← FastAPI layered architecture
│   │   ├── api/          ← Route handlers, middleware
│   │   ├── services/     ← Business logic
│   │   ├── domain/       ← State machines, enums, validation
│   │   ├── repositories/ ← Database abstraction
│   │   ├── schemas/      ← Pydantic I/O models
│   │   ├── db/           ← SQLAlchemy + session
│   │   └── core/         ← config, logging, metrics, errors
│   ├── tests/
│   │   ├── unit/         ← State machine, processing, validation
│   │   ├── api/          ← Endpoint tests
│   │   ├── integration/
│   │   ├── failure/
│   │   └── regression/
│   ├── docs/
│   │   ├── audits/       ← 5 audit documents (QA, CI/CD, Security, Docker, Release)
│   │   ├── command-center/
│   │   └── *.md          ← Architecture, RCA, traceability, observability docs
│   ├── benchmarks/       ← Concurrency baseline + transformed results (JSON)
│   ├── scripts/
│   │   ├── run_tests.sh      ← Bash script (minimal, set -e, BASH_SOURCE)
│   │   ├── start_dev.sh
│   │   ├── smoke_test.py
│   │   ├── run_checks.py
│   │   └── validate_traceability.py
│   ├── Dockerfile            ← Multi-stage build, non-root user, HEALTHCHECK
│   ├── docker-compose.yml    ← Single-service compose with healthcheck
│   ├── pyproject.toml        ← Ruff, pytest, coverage config
│   └── requirements*.txt
├── reference/
│   └── Kishan_R_Resume.md
└── README.md
```

### Verified Capability Artifacts (FACT — agent-observed)

| Capability | Artifact | Notes |
|---|---|---|
| **Docker** | `servicepulse/Dockerfile` | Multi-stage, non-root user, HEALTHCHECK, EXPOSE 8000/7860, CMD uvicorn |
| **Docker Compose** | `servicepulse/docker-compose.yml` | Single service, healthcheck, volume mount, env vars |
| **GitHub Actions CI** | `.github/workflows/ci.yml` | 4-stage pipeline: lint → security → test → docker |
| **Ruff (linting/formatting)** | `ci.yml` + `pyproject.toml` | `ruff check .` + `ruff format --check .`, target py312 |
| **Bandit (SAST)** | `ci.yml` | `bandit -r servicepulse/app -ll -ii` |
| **pip-audit** | `ci.yml` | `pip-audit -r servicepulse/requirements.txt` |
| **pytest with coverage** | `ci.yml` + `pyproject.toml` | `--cov-fail-under=85`, multi-level test hierarchy |
| **Smoke testing** | `scripts/smoke_test.py` | Python HTTP smoke test run against live container in CI |
| **Bash scripting** | `scripts/run_tests.sh` | Minimal: set -e, BASH_SOURCE, pip install check, pytest invocation |
| **Structured logging** | `app/core/logging.py` (inferred), `docs/observability.md` | JSON logs, correlation IDs |
| **Metrics** | `app/core/metrics.py` (inferred), `/api/v1/metrics` endpoint | In-process counters/histograms |
| **RCA documentation** | `docs/RCA_001_concurrent_id_generation.md` | UUIDv4 concurrency RCA |
| **Incident management** | `servicepulse` domain + tests | State machine, lifecycle, failure simulation |
| **Test coverage** | README claims 94.62%, 83 tests | ASSUMPTION: accurate at time of last commit; not re-run locally |
| **Repository pattern** | Inferred from architecture doc | SQLite → PostgreSQL swap via `DATABASE_URL` |
| **Git** | WiproGoal has clean history | FACT: 10+ commits observed |

### What is NOT Present in WiproGoal (FACT — verified by inspection)

- No Kubernetes manifests (no `k8s/`, no `.yaml` with `kind: Deployment`)
- No Terraform (no `.tf` files)
- No GitLab CI/CD (no `.gitlab-ci.yml`)
- No Linux system administration scripts (no `sysctl`, `iptables`, `systemd`, `ufw`, `netstat` usage)
- No Bash scripts beyond minimal wrappers (`run_tests.sh` is ~28 lines, no complex logic)
- No networking configuration evidence
- No firewall rule management
- No cloud infrastructure provisioning
- No Kubernetes operations documentation

---

## 3. DB Requirement Matrix

| DB Requirement | Existing Evidence | Evidence Location | Evidence Strength | Gap | Recommended Action |
|---|---|---|---|---|---|
| **GitLab CI/CD** | GitHub Actions pipeline (conceptually similar) | `.github/workflows/ci.yml` | **WEAK** — GitHub Actions, not GitLab. Syntax differs. No `.gitlab-ci.yml` exists. | HIGH GAP — Different product, different YAML schema, different runner model | Build `.gitlab-ci.yml` demonstrating stages, artifacts, rules, environments in DBPlatformGoal |
| **Git branching strategies** | WiproGoal uses master/main | `.github/dependabot.yml`, `ci.yml` on: push branches | **MODERATE** — Git is used but no explicit branching strategy documented | MEDIUM GAP — No Git Flow, trunk-based, or feature-branch strategy document | Create branching strategy doc + demonstrate with history in DBPlatformGoal |
| **Docker** | Multi-stage Dockerfile, docker-compose, CI smoke test | `servicepulse/Dockerfile`, `docker-compose.yml` | **STRONG** — Real multi-stage build with non-root, HEALTHCHECK, compose | MINOR GAP — No docker network creation, no multi-service compose | Reuse ServicePulse Dockerfile as workload; extend compose for multi-service |
| **Kubernetes — deploy/maintain** | None | — | **NONE** | CRITICAL GAP | Build Kubernetes manifests (Deployment, Service, ConfigMap, Secret) for ServicePulse |
| **Kubernetes architecture** | None | — | **NONE** | CRITICAL GAP | Document and demonstrate: Pod, ReplicaSet, Deployment, Service, Namespace, RBAC |
| **Kubernetes operations/troubleshoot** | None | — | **NONE** | CRITICAL GAP | Demonstrate: kubectl commands, log inspection, describe, exec, rollout, failure scenario |
| **Terraform / IaC** | None | — | **NONE** | HIGH GAP | Create Terraform configuration (local or cloud-free) covering: provider, resource, module, output, state |
| **Linux administration** | `set -e`, `BASH_SOURCE` in shell script | `scripts/run_tests.sh` | **VERY WEAK** — Minimal shell use, no system-level admin tasks | HIGH GAP | Demonstrate: file permissions, process management, journalctl, systemctl concepts, user management |
| **Bash scripting + automation** | Two shell scripts (minimal complexity) | `scripts/run_tests.sh`, `scripts/start_dev.sh` | **WEAK** — Scripts exist but trivial: no functions, no argument parsing, no error handling beyond `set -e` | HIGH GAP | Build structured Bash tooling: argument parsing, logging, error handling, idempotency |
| **Networking fundamentals** | None | — | **NONE** | MEDIUM GAP | Document/demonstrate: IP addressing, subnets, DNS, ports, routing concepts with practical evidence |
| **Firewall concepts** | None | — | **NONE** | MEDIUM-LOW GAP | Demonstrate: iptables basics, UFW rules, or equivalent in documented, testable form |
| **Monitor/troubleshoot/optimize perf** | Metrics endpoint, RCA document, benchmarks | `docs/RCA_001_*.md`, `benchmarks/` | **MODERATE** — RCA exists, metrics exist, benchmarks exist | MEDIUM GAP — No infrastructure-level monitoring; only app-level | Add infra monitoring layer (Prometheus + Grafana in Kubernetes context) |
| **Incident management / RCA** | Full incident domain, RCA doc, state machine | `servicepulse/domain/`, `docs/RCA_001_*.md` | **STRONG** — Demonstrated pattern and documented RCA | MINOR GAP — Not framed in platform/infra context | Reference WiproGoal RCA; create a platform-focused incident in DBPlatformGoal |
| **Platform security / availability** | Non-root Docker user, pip-audit, Bandit | `Dockerfile`, `ci.yml` | **MODERATE** — Application security shown | GAP — No RBAC, no secret management, no network policy | Demonstrate in Kubernetes: RBAC, Secrets, NetworkPolicy |
| **Deployment process improvement** | CI pipeline, smoke test | `ci.yml`, `scripts/smoke_test.py` | **MODERATE** — Pipeline exists, gates enforced | GAP — No deployment strategy (rolling, blue/green, canary) | Demonstrate Kubernetes rolling update strategy |

---

## 4. Reusable Assets

| Asset | Location | Reusable? | How |
|---|---|---|---|
| **ServicePulse Dockerfile** | `WiproGoal/servicepulse/Dockerfile` | **YES — reference** | Use as the containerized workload that the DB portfolio's platform (k8s, CI, IaC) operates. Do not copy; reference. |
| **ServicePulse docker-compose.yml** | `WiproGoal/servicepulse/docker-compose.yml` | **YES — conceptually** | Extend in DBPlatformGoal with postgres sidecar to demonstrate multi-service compose |
| **CI pipeline structure (GitHub Actions)** | `.github/workflows/ci.yml` | **YES — pattern only** | Use as reference architecture to translate into `.gitlab-ci.yml` syntax |
| **Smoke test pattern** | `servicepulse/scripts/smoke_test.py` | **YES — reference** | Re-use testing approach in platform health checks |
| **RCA document** | `docs/RCA_001_concurrent_id_generation.md` | **YES — reference** | Cross-reference from DB portfolio's platform incident docs |
| **Structured logging / metrics** | `app/core/logging.py`, `app/core/metrics.py` | **YES — reference** | Point to as the app-level signal that platform monitoring consumes |
| **Bash script skeleton** | `scripts/run_tests.sh` | **YES — pattern** | Use `set -e`, `BASH_SOURCE`, script conventions as starting idiom for DBPlatformGoal's more complex Bash tooling |
| **requirements traceability** | `docs/traceability-matrix.md` | **YES — pattern** | Apply same traceability principle to DB portfolio: platform requirement → manifest/config → test |
| **pyproject.toml / Ruff / pytest config** | `servicepulse/pyproject.toml` | **YES — if Python used** | Any Python tooling in DB portfolio can inherit this quality standard |
| **Architecture documentation style** | `docs/architecture.md` | **YES — pattern** | Use Mermaid + ADR format for DB portfolio architecture docs |

**What should NOT be copied:**  
- The servicepulse Python application code itself (it is not the portfolio subject here; it is the workload)
- The portfolio-site Next.js code
- Node modules, venv directories, compiled artifacts
- Coverage XML, .coverage, .db files

---

## 5. Capability Gaps

Ranked by importance to the DB role:

### P0 — Blocking (No evidence whatsoever; core to the role)

| Gap | Justification |
|---|---|
| **Kubernetes manifests + operations** | Listed explicitly: "Build, deploy, and maintain containerized applications using Kubernetes." Zero evidence in existing portfolio. Highest-signal capability for a platform engineer. |
| **GitLab CI/CD** | Listed first in responsibilities. The existing GitHub Actions pipeline demonstrates CI/CD concepts but is a different product entirely. Hiring managers will look for `.gitlab-ci.yml`. |
| **Terraform / IaC** | Explicitly listed: "Provision and manage infrastructure using Infrastructure as Code tools such as Terraform." Zero evidence. |

### P1 — High (Weak or absent evidence; important to demonstrably close)

| Gap | Justification |
|---|---|
| **Bash scripting complexity** | Role requires "develop and maintain automation scripts using Bash." Existing scripts are trivial (~28 lines each, no argument parsing, no complex logic). Need a real automation script with functions, flags, error handling, logging. |
| **Linux administration evidence** | "Administer and troubleshoot Linux-based environments." No demonstrated evidence. Even local documentation of commands run (with outputs) would strengthen this. |
| **Kubernetes troubleshooting scenarios** | "Monitor, troubleshoot, and optimize application and infrastructure performance." Need demonstrated failure injection and recovery at the k8s layer. |

### P2 — Medium (Gaps worth filling but existing evidence partially covers)

| Gap | Justification |
|---|---|
| **Networking fundamentals** | "Networking fundamentals, firewall concepts" listed as requirements. No direct evidence. Partially coverable through Kubernetes networking (Service, Ingress) but explicit documentation helps. |
| **Firewall concepts** | Related to Linux admin. Demonstrable via documented `iptables`/`ufw` scenarios or NetworkPolicy in Kubernetes. |
| **Deployment strategies (rolling, blue/green)** | Not explicitly stated but implied by platform engineering. Easy to demonstrate via Kubernetes strategy field. |
| **Git branching strategy** | Existing Git use is undocumented strategically. A simple branching strategy doc closes this. |
| **Platform-level monitoring** | App-level metrics exist. Need infra-layer: Prometheus + Grafana in Kubernetes, or equivalent. |

---

## 6. Proposed DB Portfolio Direction

> **PROPOSED ARCHITECTURE — not implemented, not verified. Conceptual only.**

### Core Premise

Use **ServicePulse** (from WiproGoal, referenced not copied) as the workload. Build the platform around it. This creates a coherent narrative:

> "I built the application. Now I operate it as a platform engineer."

### Narrative Arc

```
CONTAINERIZE → CI/CD (GitLab) → INFRASTRUCTURE AS CODE (Terraform) 
→ KUBERNETES DEPLOY → AUTOMATE (Bash) → OBSERVE → BREAK → RCA → FIX
```

### Proposed Monorepo Structure

```
DBPlatformGoal/
├── .gitlab-ci.yml              ← GitLab CI/CD pipeline
├── README.md                   ← Portfolio overview
├── platform/
│   ├── kubernetes/             ← K8s manifests
│   │   ├── base/               ← Deployment, Service, ConfigMap, Secret
│   │   ├── overlays/           ← dev / staging environments (optional Kustomize)
│   │   └── RUNBOOK.md
│   ├── terraform/              ← IaC (local or cloud-free)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── monitoring/             ← Prometheus/Grafana configs or manifests
├── scripts/                    ← Bash automation library
│   ├── platform-check.sh       ← Full environment validation script
│   ├── deploy.sh               ← Kubernetes deploy wrapper
│   ├── rollback.sh
│   └── lib/                    ← Reusable Bash functions
├── docs/
│   ├── architecture.md
│   ├── branching-strategy.md
│   ├── linux-runbook.md        ← Linux admin evidence
│   ├── networking.md           ← Networking + firewall concepts documented
│   ├── incidents/
│   │   └── INC-001-*.md        ← Platform incident + RCA
│   └── troubleshooting/
│       └── kubernetes-scenarios.md
└── evidence/                   ← Captured outputs (kubectl, terraform plan, etc.)
    ├── k8s-apply-output.txt
    └── terraform-plan-output.txt
```

### Technology Choices (Proposed, not decided)

| Technology | Proposed Approach |
|---|---|
| Kubernetes | Local: kind (Kubernetes in Docker) or minikube — zero cost, full k8s API |
| Terraform | Local provider first (for learning evidence); can target kind or local Docker |
| GitLab CI/CD | Self-hosted GitLab CE in Docker, or GitLab.com free tier with a local runner |
| Bash | Hand-written; tested with bats-core |
| Monitoring | Prometheus + Grafana via Helm charts on local k8s cluster |

---

## 7. Risks

### Technical Risks

| Risk | Severity | Notes |
|---|---|---|
| Local Kubernetes cluster instability on Windows | MEDIUM | kind/minikube on Windows can be finicky. WSL2 backend is more stable. Must test early. |
| GitLab local setup complexity | LOW-MEDIUM | GitLab CE in Docker is feasible but heavyweight. Free-tier GitLab.com avoids this. |
| Terraform with no cloud target | LOW | Local Docker provider or kind provider is sufficient for evidence but interviewers may push on cloud |
| Windows vs Linux shell differences | MEDIUM | Bash scripts must be testable. WSL2 or Git Bash differences from real Linux must be acknowledged. |

### Scope Risks

| Risk | Severity | Notes |
|---|---|---|
| Scope creep (adding too many tools) | HIGH | Kubernetes + GitLab + Terraform + Bash + Linux + Monitoring is already large. Do not add EKS, ArgoCD, Vault, etc. unless time permits. |
| Depth vs breadth tradeoff | HIGH | A shallow "hello world" Kubernetes deployment with no troubleshooting is weak evidence. Depth on fewer tools beats breadth on many. |
| Over-engineering the portfolio structure | MEDIUM | Don't create 5 independent repos for one portfolio. One repo is cleaner and more demonstrable. |

### Credibility Risks

| Risk | Severity | Notes |
|---|---|---|
| Personal/project framing | LOW (manageable) | Must clearly frame everything as personal project evidence, not professional experience. This is the explicit strategy. |
| Claims without runnable evidence | HIGH | Any Kubernetes or Terraform work must be runnable locally. Evidence must be captured (output files, terminal recordings). |
| Fabricating benchmark values | ELIMINATE | Zero tolerance. All metrics must come from actual local runs. |
| ServicePulse dependency | MEDIUM | If ServicePulse breaks or its dependencies become stale, the platform demo may fail. Need a dependency plan. |

### Duplication Risks

| Risk | Severity | Notes |
|---|---|---|
| Copying WiproGoal code into DBPlatformGoal | LOW (avoidable) | Strategy is reference, not copy. Must be maintained. |
| Accidentally modifying WiproGoal | LOW | WiproGoal is in a separate directory with its own Git repo. Risk is minimal with discipline. |

### Deployment Risks

| Risk | Severity | Notes |
|---|---|---|
| Local resource constraints | UNKNOWN | Running kind + GitLab runner + Prometheus + Grafana locally may exceed available RAM. Must profile. |
| Windows permission issues for Linux containers | MEDIUM | Some containers assume Linux filesystem semantics. WSL2 usually resolves this. |

---

## 8. Recommended Next Step

**ONE action only:**

> **Initialize the DBPlatformGoal Git repository and establish the minimal scaffolding: root `README.md` (stating portfolio purpose, framing, and technology plan), `.gitignore`, and directory skeleton — without implementing any platform code.**

Rationale:  
- The workspace exists but has no Git history. A committed skeleton establishes the independent narrative.  
- The README at this stage should lock in the framing (personal project, not professional experience) and the technology choices (kind, Terraform local, GitLab.com or local CE, Bash).  
- This is reversible, low-risk, and does not require any technology decisions about cloud provider or GitLab hosting.  
- Architecture decisions about Kubernetes provider and GitLab hosting need to be confirmed with you before implementation begins.

---

## 9. Validation

### What Was Inspected (Agent-Observed)

| Item | Inspected | Method |
|---|---|---|
| `E:\Projects\VSCode\PostOmniroute\` — parent directory listing | ✅ | `ls -la` |
| `WiproGoal/` — top-level directory listing | ✅ | `ls -la` |
| `WiproGoal/.github/workflows/ci.yml` — full file read | ✅ | Read tool |
| `WiproGoal/servicepulse/Dockerfile` — full file read | ✅ | Read tool |
| `WiproGoal/servicepulse/docker-compose.yml` — full file read | ✅ | Read tool |
| `WiproGoal/servicepulse/pyproject.toml` — full file read | ✅ | Read tool |
| `WiproGoal/servicepulse/scripts/run_tests.sh` — full file read | ✅ | Read tool |
| `WiproGoal/servicepulse/docs/architecture.md` — full file read | ✅ | Read tool |
| `WiproGoal/README.md` — full file read | ✅ | Read tool |
| `WiproGoal/servicepulse/` — directory listing | ✅ | `ls -la` |
| `WiproGoal/servicepulse/tests/` and `app/` — listing | ✅ | `ls` |
| `WiproGoal/servicepulse/docs/` — listing | ✅ | `ls` |
| `WiproGoal/servicepulse/benchmarks/` — listing | ✅ | `ls` |
| `WiproGoal/servicepulse/scripts/` — listing | ✅ | `ls` |
| `WiproGoal/servicepulse/docs/audits/` — listing | ✅ | `ls` |
| `WiproGoal/` — search for k8s/terraform/gitlab keywords | ✅ | `grep -r -l` |
| `WiproGoal/` — find all `.sh` files | ✅ | `find` |
| `WiproGoal/` — git log (read-only) | ✅ | `git log --oneline -10` |
| `DevOpsPlatformEngineer/` — directory listing | ✅ | `ls -la` |
| `kishan-portfolio/` — directory listing | ✅ | `ls -la` |
| `DBPlatformGoal/` — created and verified empty | ✅ | `mkdir + ls` |

### What Was NOT Validated

| Item | Status |
|---|---|
| Test suite actually passing (83 tests, 94.62% coverage) | NOT RUN — took as stated in README/badges. Not re-executed locally. |
| Docker build actually succeeds | NOT RUN — CI pipeline reads as correct; image not built locally. |
| Live deployment on Render.com | NOT ACCESSED — URL cited in README not fetched. |
| `WiproGoal/.github/workflows/release.yml` | NOT READ — listing confirmed it exists; full content not inspected. |
| `WiproGoal/servicepulse/docs/audits/*.md` (beyond B_ header) | ONLY FIRST 40 LINES OF B_ READ — remainder not inspected. |
| `WiproGoal/servicepulse/docs/observability.md` | NOT READ — existence confirmed via architecture.md reference. |
| `WiproGoal/kishan-portfolio/` inner structure | NOT READ — listed at root level only. |
| `WiproGoal/reference/Kishan_R_Resume.md` | NOT READ — only listing inspected. |
| Whether WiproGoal's remote (`github.com/KishanR-dev/engineering-quality-cicd`) is live | NOT CHECKED — URL visible in README, not fetched. |
| Whether `DevOpsPlatformEngineer/.claude/` contains anything relevant | NOT READ — only top-level listing done. |

### Distinctions

- **Agent-observed:** All items in the "inspected" table above.  
- **Independently verified:** Nothing. No tests were run, no CI was triggered, no live endpoints were hit.  
- All claims about capability strength are inferences from file content, not from execution.

---

*End of Discovery Report — Phase 1 complete. Awaiting instruction before proceeding.*

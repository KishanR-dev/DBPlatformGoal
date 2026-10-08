# Workload & Container Contract — ServicePulse Reference Workload

**Document Version:** 1.0.0  
**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Reference Source:** `E:\Projects\VSCode\PostOmniroute\WiproGoal\servicepulse` (READ-ONLY)  
**Status:** Approved Architectural Contract — Implementation Ready  

---

## 1. Workload Identity

**What ServicePulse is:**  
ServicePulse is a modular monolith production operations and incident management service developed using FastAPI (Python 3.12), SQLAlchemy 2.0, and Pydantic v2. It provides customer service request lifecycle orchestration, incident state machines with root-cause analysis (RCA) tracking, Prometheus-compatible metric exposition, and JSON-structured audit logging.

**Why it serves as the DB Platform reference workload:**  
Instead of operating an unrealistic "hello-world" container or an unvetted third-party demo, the DB Platform Engineering portfolio operates ServicePulse because:
1. **Realistic Lifecycle:** It features distinct startup, database initialization, health probes, and shutdown lifecycles.
2. **Integrated Observability:** It exposes standard Prometheus metrics (`/api/v1/metrics`) and structured JSON logs with correlation IDs.
3. **State Management:** It requires persistent storage (SQLite by default, switchable to PostgreSQL via `DATABASE_URL`).
4. **Failure Simulation:** It includes an opt-in failure simulation engine suitable for demonstrating platform self-healing, alerting, and incident RCA.
5. **No Synthetic Workload:** It avoids fabricating an application from scratch; platform engineering focuses entirely on *operating*, *automating*, *securing*, and *recovering* the workload.

---

## 2. Source Evidence from WiproGoal

All facts below were directly inspected and verified from `E:\Projects\VSCode\PostOmniroute\WiproGoal\servicepulse` on 2025-10-08:

| Subsystem / Property | Source File | Inspected Fact | Classification |
|---|---|---|---|
| **Entrypoint** | `app/main.py:25-48` | Uses FastAPI `lifespan` context manager. Executes `setup_logging()`, `init_db()`, and increments `app_startup_total` on start; logs `APP_SHUTDOWN` on exit. | Verified from existing project |
| **HTTP Framework** | `pyproject.toml`, `requirements.txt` | Python `>=3.11` (runtime 3.12), `fastapi==0.142.2`, `uvicorn[standard]==0.34.3`, `pydantic==2.11.4`. | Verified from existing project |
| **Routing** | `app/main.py:146-150` | Mounts `health.router` at `/health`, `requests.router` at `/api/v1/requests`, `incidents.router` at `/api/v1/incidents`, `metrics.router` at `/api/v1/metrics`. | Verified from existing project |
| **Health Check** | `app/api/routes/health.py:18-50` | Single `GET /health` endpoint. Runs `SELECT 1` on the database session. Returns HTTP 200 with component statuses if healthy, or HTTP 503 if DB fails. | Verified from existing project |
| **Readiness Check** | `app/api/routes/health.py` | **NO separate `/ready` or `/readiness` endpoint exists.** System relies on `/health`. | Verified from existing project |
| **Metrics** | `app/api/routes/metrics.py:36-55` | Exposes Prometheus text format at `GET /api/v1/metrics` and JSON snapshot at `GET /api/v1/metrics/json`. | Verified from existing project |
| **Logging** | `app/core/logging.py:9-62` | Custom `StructuredFormatter` emits single-line JSON to `sys.stdout`. Captures `timestamp`, `level`, `logger`, `message`, `event`, `correlation_id`, `duration_ms`. | Verified from existing project |
| **Correlation IDs** | `app/main.py:56-116` | `CorrelationIdMiddleware` extracts `X-Correlation-ID` or `X-Request-ID`, generates 8-char UUID prefix if missing, and echoes in response header. | Verified from existing project |
| **Database** | `app/db/database.py:18-60` | SQLAlchemy 2.0 with WAL mode enabled for SQLite (`PRAGMA journal_mode=WAL;`). Auto-creates schema via `Base.metadata.create_all()` on startup. | Verified from existing project |
| **Configuration** | `app/core/config.py:6-37` | `pydantic_settings.BaseSettings` reading environment variables: `APP_ENV`, `APP_NAME`, `APP_VERSION`, `APP_HOST`, `APP_PORT`, `LOG_LEVEL`, `DATABASE_URL`, `FAILURE_SIMULATION_ENABLED`. | Verified from existing project |
| **Existing Dockerfile** | `Dockerfile:1-41` | Multi-stage build (`python:3.12-slim` builder $\to$ production). Creates `appuser` (UID 1000). Writable directory `/app/data`. Runs uvicorn on port 8000. | Verified from existing project |
| **Existing Compose** | `docker-compose.yml:1-26` | Service `servicepulse`, maps port 8000:8000, mounts volume `./data:/app/data`, defines healthcheck via python `urllib`. | Verified from existing project |
| **Smoke Suite** | `scripts/smoke_test.py:1-150` | Standalone zero-dependency Python script testing `/`, `/health`, and `/api/v1/metrics`. | Verified from existing project |

### 2.1 Source Strategy & Minimum Legitimate Application Source Set

To maintain total repository self-containment for `DBPlatformGoal` without modifying `WiproGoal` or creating an unportable Windows filesystem dependency in future GitLab CI/CD environments, the smallest legitimate application source boundary is defined and imported into `src/servicepulse/`:

- **Included Assets (Minimum Set):**
  - `app/` — Full application package (`api/`, `core/`, `db/`, `domain/`, `repositories/`, `schemas/`, `services/`, `__init__.py`, `main.py`).
  - `requirements.txt` — Frozen core runtime dependencies (`fastapi`, `uvicorn`, `pydantic`, `pydantic-settings`, `sqlalchemy`, `python-dotenv`).
  - `pyproject.toml` — Package metadata and project configuration.
- **Excluded Assets (Out of Runtime Scope):**
  - `tests/` — Test suites (not required for runtime image execution).
  - `benchmarks/` — Performance testing scripts.
  - `docs/` — Application documentation.
  - `scripts/` — Development/host helper scripts.
  - `venv/`, `.pytest_cache/`, `.ruff_cache/`, `*.pyc` — Ephemeral local environment caches.
  - `servicepulse.db`, `data/` — Ephemeral database state (clean container initializes DB on startup).
- **Source Provenance:** Frozen release snapshot from `WiproGoal/servicepulse` (v1.1.0 baseline), keeping WiproGoal strictly read-only. (Design decision)

---

## 3. Target Container Contract

### 3.1 Image Specification
- **Image Name:** `dbplatform/servicepulse` (local kind repository: `servicepulse`)
- **Tagging Convention:**
  - Semantic Release: `v1.4.0` (Design decision)
  - Git Commit SHA: `git-<short_sha>` (e.g., `git-9326d12`) (Design decision)
  - CI Build Tag: `ci-$CI_COMMIT_SHORT_SHA` (Design decision)
  - **Rule:** The `latest` tag is prohibited in all Kubernetes manifests and deployment specifications. (Design decision)
- **Target Architecture:** `linux/amd64` (Verified host & kind runtime architecture)
- **Base Image:** `python:3.12-slim` (official Debian-based minimal image) (Verified from existing project)

### 3.2 Runtime & Networking Contract
- **Protocol:** HTTP/1.1 (Verified from existing project)
- **Container Port:** `8000` (TCP) (Verified from existing project)
- **Service Port:** `80` (mapped to targetPort 8000 via Kubernetes ClusterIP) (Design decision)
- **Startup Command:** `uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1` (Design decision)
- **Traffic Direction:** Inbound HTTP requests; outbound database queries (if external DB) or strictly internal loopback (SQLite). No outbound internet access required at runtime. (Design decision)

### 3.3 Health & Probe Contract
- **Liveness Probe Endpoint:** `GET /health` (port 8000) (Verified from existing project)
  - *Expectation:* HTTP 200 OK. If HTTP 503 or timeout, container is failing.
  - *Initial Delay:* 10 seconds. (Design decision)
  - *Period:* 15 seconds. (Design decision)
  - *Failure Threshold:* 3 attempts. (Design decision)
- **Readiness Probe Endpoint:** `GET /health` (port 8000) (Design decision)
  - *Expectation:* HTTP 200 OK before routing ingress traffic.
  - *Initial Delay:* 5 seconds. (Design decision)
  - *Period:* 10 seconds. (Design decision)
  - *Failure Threshold:* 2 attempts. (Design decision)
  - *Note on Gap:* ServicePulse currently does not decouple readiness from liveness; `/health` performs a database check. If the database drops, both probes fail. (Verified from existing project)
- **Startup Probe Endpoint:** `GET /health` (port 8000) (Design decision)
  - *Initial Delay:* 2 seconds.
  - *Period:* 3 seconds.
  - *Failure Threshold:* 10 attempts (protects slow disk I/O on table creation).

### 3.4 Termination & Lifecycle
- **Signal Handling:** uvicorn natively intercepts `SIGTERM` and `SIGINT`, ceases accepting new connections, drains active HTTP requests, and invokes the `lifespan` context teardown. (Verified from existing project)
- **Termination Grace Period:** Kubernetes `terminationGracePeriodSeconds: 30` (Design decision)

### 3.5 Security Context Contract
- **User / Group:** `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000` (Verified from existing project / Design decision)
- **Privilege Escalation:** `allowPrivilegeEscalation: false` (Design decision)
- **Linux Capabilities:** `capabilities: { drop: ["ALL"] }` (Design decision)
- **Filesystem Immutability:** `readOnlyRootFilesystem: true` (Design decision)
  - Writable mounts: An `emptyDir` mounted at `/app/data` (for SQLite WAL database) and an `emptyDir` mounted at `/tmp` (for temp files). (Design decision)
- **Credential Storage:** Hardcoding secrets or credentials in the container image or filesystem is strictly prohibited. (Design decision)

### 3.6 Resource Allocation (Design Values)
These are initial operational design estimates for single-replica local kind cluster testing, not measured production boundaries:

| Resource Metric | Request (Design) | Limit (Design) | Rationale |
|---|---|---|---|
| **CPU** | `100m` (0.1 vCPU) | `500m` (0.5 vCPU) | FastAPI/uvicorn idle uses <0.02 vCPU; 500m accommodates burst JSON serialization. |
| **Memory** | `128Mi` | `256Mi` | Baseline resident memory in Python 3.12 is ~45–60 MiB. 256Mi provides safe buffer before OOM. |

---

## 4. Configuration & Secret Boundaries

Configuration is strictly divided into three isolated tiers:

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. BUILD-TIME (Baked into Image)                            │
│    - Python 3.12 interpreter & standard library             │
│    - Frozen pip dependencies (requirements.txt)             │
│    - Application code (/app)                                │
│    - pyproject.toml package metadata                        │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 2. RUNTIME CONFIGURATION (Kubernetes ConfigMap)             │
│    - APP_ENV=production / staging / development             │
│    - APP_NAME=ServicePulse                                  │
│    - APP_HOST=0.0.0.0                                       │
│    - APP_PORT=8000                                          │
│    - LOG_LEVEL=INFO                                         │
│    - FAILURE_SIMULATION_ENABLED=false                       │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 3. SENSITIVE CREDENTIALS (Kubernetes Secret)                │
│    - DATABASE_URL (when connecting to PostgreSQL)           │
│    - In SQLite mode: DATABASE_URL is non-secret (ConfigMap) │
│    - Any future external API tokens                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Deployment & Rollback Strategy

- **Deployment Kind:** Kubernetes `apps/v1` `Deployment` (Design decision)
- **Replica Strategy:**
  - In SQLite mode: `replicas: 1` (SQLite does not safely support multi-writer concurrent pod access across network filesystems). (Design decision)
  - In PostgreSQL mode (future): `replicas: 2+` with HorizontalPodAutoscaler. (Planned)
- **Update Strategy:** `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0` (for stateless / DB-backed configurations). (Design decision)
- **Rollback Mechanism:**
  - Automated: `kubectl rollout undo deployment/servicepulse` on health probe failure. (Design decision)
  - Pipeline: GitLab CI explicit `rollback` job referencing prior immutable image tag. (Design decision)

---

## 6. Observability Contract

| Signal Type | Implementation in Workload | Platform Ingestion Mechanism | Status |
|---|---|---|---|
| **Structured Logs** | Single-line JSON emitted to `sys.stdout` with timestamp, level, event, correlation_id, status_code, duration_ms | Standard container stdout ingested via Kubernetes log driver (`kubectl logs`) / Promtail | Verified from existing project |
| **Application Metrics** | Prometheus text exposition at `/api/v1/metrics` | Prometheus Operator / Prometheus server scraping `servicepulse:8000/api/v1/metrics` every 15s | Verified from existing project |
| **JSON Metrics** | Machine-readable JSON snapshot at `/api/v1/metrics/json` | REST polling / automated diagnostic check scripts | Verified from existing project |
| **Health State** | HTTP status at `/health` | Kubernetes liveness/readiness probes + platform health-check scripts | Verified from existing project |
| **Trace Context** | `X-Correlation-ID` header generated & echoed in all responses | Distributed tracing / log correlation via correlation_id | Verified from existing project |

---

## 7. Platform Interface (The 10 Operational Questions)

The platform operating environment must deterministically answer these 10 operational questions:

1. **What image should I run?**  
   `dbplatform/servicepulse:<immutable-tag>`, built deterministically via the multi-stage Dockerfile from WiproGoal source. (Design decision)
2. **What port should I expose?**  
   Container port `8000` TCP, mapped to Service port `80`. (Verified from existing project)
3. **How do I know the application is healthy?**  
   `GET /health` returns HTTP 200 and JSON with `"status": "healthy"`. (Verified from existing project)
4. **What configuration does it need?**  
   `APP_ENV`, `APP_PORT`, `LOG_LEVEL`, `DATABASE_URL`, supplied via Kubernetes ConfigMap. (Verified from existing project)
5. **What secrets does it need?**  
   Zero secrets required for SQLite; PostgreSQL connection string required if relational DB is attached. (Verified from existing project)
6. **How much CPU/memory does it initially need?**  
   Initial design requests: `100m` CPU, `128Mi` RAM. Limits: `500m` CPU, `256Mi` RAM. (Design decision)
7. **How should it shut down?**  
   Send `SIGTERM`. uvicorn drains in-flight requests and executes lifespan teardown within 30 seconds. (Verified from existing project)
8. **How should it be upgraded?**  
   Update deployment image tag $\to$ Kubernetes initiates RollingUpdate $\to$ startup probe validates new pod before old pod is terminated. (Design decision)
9. **How should it be rolled back?**  
   `kubectl rollout undo deployment/servicepulse` or redeploying prior image tag via GitLab CI. (Design decision)
10. **How should failures be detected?**  
    Pod crashes via Kubernetes restart count; probe failures via `Unhealthy` events in `kubectl describe`; error rates via Prometheus `http_requests_total{status=~"5.."}` alerts. (Design decision)

---

## 8. Known Gaps & Workload Mitigations

| Identified Gap | Severity | Platform Mitigation / Decision | Classification |
|---|---|---|---|
| **No decoupled `/ready` probe** | Low | Currently `/health` performs a database query. A transient DB slowdown will cause readiness and liveness to fail together. *Mitigation:* Platform probe will use `/health` with generous timeouts (`timeoutSeconds: 3`, `failureThreshold: 3`). | Verified from existing project / Design decision |
| **SQLite single-pod constraint** | Medium | SQLite database in `/app/data` prevents multi-replica horizontal scaling. *Mitigation:* Platform runs `replicas: 1` initially; future phase can introduce a PostgreSQL container if horizontal scaling evidence is needed. | Verified from existing project / Design decision |
| **Prometheus path is `/api/v1/metrics`** | Low | Standard Prometheus default is `/metrics`. *Mitigation:* Prometheus scrape annotations or PodMonitor must explicitly declare `prometheus.io/path: "/api/v1/metrics"`. | Verified from existing project / Design decision |
| **No Graceful Shutdown env var** | Low | uvicorn timeout is default (30s). *Mitigation:* Kubernetes `terminationGracePeriodSeconds` set to `30s` to align. | Verified from existing project / Design decision |

---

## 9. Evidence Classification Index

Every claim in this document is explicitly bounded by this classification:

- **Verified from existing project:** Fact verified by direct inspection of code or configuration in `WiproGoal/servicepulse`.
- **Design decision:** Architectural choice made for `DBPlatformGoal` based on platform engineering best practices and job requirements.
- **Planned:** Future capability or enhancement scheduled for later portfolio phases.
- **Not yet tested:** Proposed behavior or value that has not yet been executed in a running cluster or test suite.

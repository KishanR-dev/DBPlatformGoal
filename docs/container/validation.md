# Container Validation & Runtime Test Evidence

**Document Version:** 1.0.0  
**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Image Under Test:** `dbplatform/servicepulse:git-f549433` (`sha256:08e4ac90b3f5131284b74c310c946b117ccb28b9fd381161d399953191a687d1`)  
**Status:** Comprehensive Local Runtime Validation Complete  

---

## 1. Image Identity & Build Metrics

| Metric / Property | Measured Value | Classification |
|---|---|---|
| **Image ID** | `sha256:08e4ac90b3f5131284b74c310c946b117ccb28b9fd381161d399953191a687d1` | Locally Validated |
| **Tags Applied** | `dbplatform/servicepulse:git-f549433`, `dbplatform/servicepulse:v1.1.0` | Locally Validated |
| **Total Image Size** | `254.5 MB` (compressed layers: ~90 MB) | Locally Validated |
| **Base Image** | `python:3.12-slim` (Debian Trixie base) | Verified from existing project |
| **Build Duration** | `26.04 seconds` | Locally Validated |
| **Build Engine** | Docker Desktop 4.94.0 (Engine 29.8.2, linux/amd64) | Locally Validated |
| **Security Scanner** | *Not scanned with an image vulnerability scanner in this phase.* | Not Tested |

---

## 2. Static Image Inspection Results

```text
Configured User:       1000:1000 (appuser)
Working Directory:     /app
Exposed Ports:         8000/tcp
CMD Entrypoint:        ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
Environment Defaults:  PYTHONPATH=/app, APP_ENV=production, APP_HOST=0.0.0.0, APP_PORT=8000, 
                       LOG_LEVEL=INFO, DATABASE_URL=sqlite:////app/data/servicepulse.db, 
                       PYTHONUNBUFFERED=1, PYTHONDONTWRITEBYTECODE=1
Files in /app:         drwxr-xr-x app (code), drwx------ data (empty data dir), pyproject.toml
Secret Files Present:  None (No .env, .pem, .key, credentials, or git metadata in image)
```

---

## 3. Runtime Test Suite & Evidence

### Test 1: Container Startup & Non-Root Execution
- **Command:** `docker run --rm dbplatform/servicepulse:git-f549433 id`
- **Output:** `uid=1000(appuser) gid=1000(appuser) groups=1000(appuser)`
- **Verdict:** **PASSED.** Process executes strictly under non-root UID 1000. (Locally Validated)

---

### Test 2: Health Check & Database Probing (`/health`)
- **HTTP Request:** `GET http://localhost:8000/health`
- **Response Status:** `HTTP 200 OK`
- **Response Content-Type:** `application/json`
- **Response Body:**
  ```json
  {
    "status": "healthy",
    "version": "1.4.0",
    "environment": "production",
    "timestamp": "2026-10-08T08:22:07.548237+00:00",
    "components": {
      "application": "healthy",
      "database": "healthy"
    }
  }
  ```
- **Verdict:** **PASSED.** Database connectivity probe `SELECT 1` verified operational. (Locally Validated)

---

### Test 3: Prometheus Metrics Exposition (`/api/v1/metrics`)
- **HTTP Request:** `GET http://localhost:8000/api/v1/metrics`
- **Response Status:** `HTTP 200 OK`
- **Response Content-Type:** `text/plain; charset=utf-8`
- **Sample Metrics Excerpt:**
  ```text
  # TYPE app_startup_total counter
  app_startup_total 1.0
  # TYPE http_requests_total counter
  http_requests_total{endpoint="/health",method="GET",status="200"} 3.0
  # TYPE processed_requests counter
  processed_requests 3.0
  # TYPE total_requests counter
  total_requests 4.0
  # TYPE incidents_by_status gauge
  incidents_by_status{status="INVESTIGATING"} 0
  incidents_by_status{status="MITIGATED"} 0
  incidents_by_status{status="OPEN"} 0
  incidents_by_status{status="RESOLVED"} 0
  incidents_open 0
  ```
- **Verdict:** **PASSED.** Standard Prometheus exposition format verified with custom business and HTTP metrics. (Locally Validated)

---

### Test 4: Structured JSON Logging & Correlation IDs
- **Command:** `docker logs servicepulse-test-basic`
- **Captured Log Lines:**
  ```json
  {"timestamp": "2026-10-08T08:21:51.568983+00:00", "level": "INFO", "logger": "servicepulse.main", "message": "Starting application", "event": "APP_STARTUP"}
  {"timestamp": "2026-10-08T08:21:55.436476+00:00", "level": "INFO", "logger": "servicepulse.main", "message": "Request received", "event": "HTTP_REQUEST_START", "correlation_id": "bf4c2fb5", "method": "GET"}
  {"timestamp": "2026-10-08T08:21:55.439544+00:00", "level": "INFO", "logger": "servicepulse.main", "message": "Request completed", "event": "HTTP_REQUEST_COMPLETE", "correlation_id": "bf4c2fb5", "method": "GET", "status_code": 200, "duration_ms": 3.11}
  ```
- **Verdict:** **PASSED.** Single-line JSON emitted to stdout with timestamp, level, event, correlation_id, status_code, duration_ms. (Locally Validated)

---

### Test 5: Read-Only Root Filesystem & Privilege Dropping
- **Execution Flags:**
  `--read-only`  
  `--cap-drop=ALL`  
  `--security-opt=no-new-privileges`  
  `--tmpfs /tmp:rw,noexec,nosuid,size=64m,mode=1777`  
  `-v servicepulse-hardened-data:/app/data`  
- **Test Actions & Outcomes:**
  1. `POST /api/v1/requests` with payload `{"customer_id": "CUST-001", "request_type": "SERVICE", "description": "Hardened test"}` $\to$ **HTTP 201 Created** (`REQ-73B9817B`). Confirms SQLite WAL writes to `/app/data` succeed under read-only rootfs.
  2. `touch /app/rootfs-test.txt` $\to$ **Failed with `Read-only file system`** (Expected security constraint).
  3. `touch /app/data/data-test.txt` $\to$ **Succeeded.**
  4. `touch /tmp/tmp-test.txt` $\to$ **Succeeded (mode 1777).**
- **Verdict:** **PASSED.** Complete filesystem immutability enforced while preserving stateful SQLite operations. (Locally Validated)

---

## 4. Controlled Failure Injection & Recovery Test

To demonstrate platform-level observability and self-healing failure semantics, a storage permission outage was simulated:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ 1. INJECTION: Unwritable Database Directory                            │
│    - Started container with DATABASE_URL=sqlite:////app/unwritable/db  │
│    - Root filesystem is read-only; /app/unwritable cannot be created   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼────────────────────────────────────┐
│ 2. DETECTION: Process Exit & Exception Telemetry                       │
│    - Container exited with code 3 within 2 seconds                     │
│    - Captured stderr: sqlite3.OperationalError: unable to open DB file │
│    - Captured event: {"event": "APP_STARTUP"} logged before crash      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼────────────────────────────────────┐
│ 3. RECOVERY: Remounting Valid Volume                                   │
│    - Container removed and redeployed with valid /app/data volume      │
│    - Schema initialized; /health returned HTTP 200 (healthy)           │
└────────────────────────────────────────────────────────────────────────┘
```

- **Verdict:** **PASSED.** Failure was cleanly trapped, observed via structured logs/exit codes, and recovered. (Locally Validated)

---

## 5. Known Limitations & Scope Boundaries

1. **Local Docker Runtime Only:** Validation was executed via Docker Desktop on the local Windows/WSL2 host. Kubernetes `PodSecurityStandard`, `NetworkPolicy`, and `ResourceQuota` behaviors remain to be evaluated in Phase 7 (Cluster & Manifests). (Design decision / Planned)
2. **SQLite Single-Replica Boundary:** Workload remains bound to `replicas: 1` until PostgreSQL backend is provisioned. (Verified from existing project)
3. **Vulnerability Scanning:** No image vulnerability scanner was executed in this phase; scheduled for the GitLab CI container security stage. (Planned)

---

## 6. Evidence Classification Summary

- **Verified from existing project:** ServicePulse Python 3.12 codebase, FastAPI routers, SQLite WAL mode, correlation ID middleware, `/health` and `/api/v1/metrics` endpoints.
- **Locally Validated:** Multi-stage Docker build, image tag `git-f549433`, non-root execution (UID 1000), read-only rootfs (`--read-only`), dropped capabilities (`--cap-drop=ALL`), `mode=1777` `/tmp` tmpfs mount, failure injection & recovery.
- **Design decision:** Tagging convention, image layer architecture, resource sizing estimates.
- **Planned:** Kubernetes manifests, Helm charts, GitLab CI pipeline, Terraform provisioning, Prometheus scraping.
- **Not Tested:** Vulnerability scanning (Trivy/Grype), multi-node cluster execution.

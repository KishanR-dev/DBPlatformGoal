# Container Build Specification — ServicePulse Workload

**Document Version:** 1.0.0  
**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Container Context:** `src/servicepulse/`  
**Dockerfile:** `container/servicepulse/Dockerfile`  
**Status:** Locally Built & Validated  

---

## 1. Build Context & Directory Architecture

The container build context is structured to keep `DBPlatformGoal` completely self-contained, reproducible, and portable across developer workstations, local kind clusters, and future GitLab CI/CD runner pipelines.

```text
DBPlatformGoal/
├── container/
│   └── servicepulse/
│       ├── Dockerfile           # Multi-stage production container definition
│       └── .dockerignore        # Build context exclusion rules
├── src/
│   └── servicepulse/            # Minimal legitimate application source set
│       ├── .dockerignore        # Context-root ignore rules
│       ├── app/                 # FastAPI application package
│       ├── pyproject.toml       # Package metadata
│       └── requirements.txt     # Frozen core runtime dependencies
└── docs/
    └── container/
        ├── build.md             # This document
        └── validation.md        # Execution evidence and runtime test reports
```

---

## 2. Source Strategy & Provenance

To satisfy the strict boundary rules between `WiproGoal` (read-only reference) and `DBPlatformGoal` (active platform repository) without introducing brittle Windows filesystem path dependencies in future CI/CD runners:

1. **Smallest Legitimate Source Boundary:**  
   Only the essential application code (`app/`), runtime package configuration (`pyproject.toml`), and frozen dependencies (`requirements.txt`) are maintained in `src/servicepulse/`. (Design decision)
2. **Excluded Non-Runtime Assets:**  
   Development virtualenvs (`venv/`), test caches (`.pytest_cache/`, `.ruff_cache/`), SQLite database files (`*.db`), benchmark suites (`benchmarks/`), and documentation (`docs/`) are strictly excluded from the build context via `.dockerignore`. (Verified from existing project / Design decision)
3. **Immutability & Provenance:**  
   Source code reflects the v1.1.0 / v1.4.0 verified release baseline of the ServicePulse application. `WiproGoal` remains 100% untouched. (Verified from existing project)

---

## 3. Multi-Stage Dockerfile Architecture

The build leverages a two-stage Docker architecture (`python:3.12-slim` base) ensuring zero build tools or package managers pollute the production image:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ STAGE 1: BUILDER (python:3.12-slim)                                     │
│                                                                         │
│  - WORKDIR /build                                                       │
│  - Installs and upgrades pip                                            │
│  - Installs frozen dependencies into isolated prefix: --prefix=/install │
│  - Discards intermediate wheel caches via --no-cache-dir                │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
                 COPY --from=builder /install /usr/local
                                     │
┌────────────────────────────────────▼────────────────────────────────────┐
│ STAGE 2: RUNTIME (python:3.12-slim)                                     │
│                                                                         │
│  - Creates non-root system user 'appuser' (UID 1000, GID 1000)          │
│  - Copies installed site-packages directly to /usr/local                │
│  - Copies /app source code with ownership chown=1000:1000               │
│  - Pre-allocates writable /app/data and /tmp directories (mode 0700)    │
│  - Drops root privileges: USER 1000:1000                                │
│  - Sets deterministic environment variables (PYTHONPATH, APP_PORT, etc) │
│  - Exposes port 8000                                                    │
│  - Configures container HEALTHCHECK against /health                     │
│  - Clean exec-form CMD: ["uvicorn", "app.main:app", ...]                │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Security & Hardening Design

| Hardening Layer | Implementation | Mechanism | Evidence Status |
|---|---|---|---|
| **Non-Root Execution** | `USER 1000:1000` | Dedicated user `appuser` (UID 1000, GID 1000) created with `/usr/sbin/nologin` shell. | Locally Validated |
| **Filesystem Immutability** | `--read-only` rootfs | Image filesystem is read-only. Writable state is restricted to explicit volume mount `/app/data` (SQLite WAL) and tmpfs `/tmp`. | Locally Validated |
| **Linux Capabilities** | `--cap-drop=ALL` | Container requires zero elevated Linux capabilities to operate. | Locally Validated |
| **Privilege Escalation** | `no-new-privileges` | Prevents setuid/setgid privilege escalation inside container processes. | Locally Validated |
| **No Shell Wrapping** | Exec-form `CMD` | Uvicorn runs directly as PID 1, receiving `SIGTERM` signals for graceful teardown without intermediate `/bin/sh` process. | Locally Validated |
| **Secrets & Keys** | Zero baked credentials | Image contains zero `.env` files, certificates, or hardcoded passwords. Database URL is dynamically injected. | Locally Validated |

---

## 5. Image Naming & Tagging Policy

- **Primary Repository:** `dbplatform/servicepulse`
- **Immutable Evidence Tag:** `dbplatform/servicepulse:git-f549433` (anchored to git commit `f549433`)
- **Semantic Version Tag:** `dbplatform/servicepulse:v1.1.0`
- **Future CI/CD Tag:** `dbplatform/servicepulse:ci-$CI_COMMIT_SHORT_SHA`
- **Prohibited:** Use of untracked `latest` tag in deployment configurations.

---

## 6. Build Commands & Reproducibility

### Local Host Build Command
```powershell
Set-Location "E:\Projects\VSCode\PostOmniroute\DBPlatformGoal"
docker build `
  -f container/servicepulse/Dockerfile `
  -t dbplatform/servicepulse:git-f549433 `
  -t dbplatform/servicepulse:v1.1.0 `
  src/servicepulse
```

### Standard Local Run Command (Hardened Runtime)
```powershell
docker run -d `
  --name servicepulse `
  --read-only `
  --cap-drop=ALL `
  --security-opt=no-new-privileges `
  --tmpfs /tmp:rw,noexec,nosuid,size=64m,mode=1777 `
  -v servicepulse-data:/app/data `
  -p 8000:8000 `
  dbplatform/servicepulse:git-f549433
```

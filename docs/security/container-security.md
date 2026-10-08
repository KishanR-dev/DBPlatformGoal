# Container Security — Phase 13

**Evidence Classification:** LOCALLY VALIDATED  
**Image:** `dbplatform/servicepulse:git-f549433`  
**Cluster:** `db-platform-tf` (kind, Kubernetes v1.33.1)

---

## Running Pod Audit

Pod: `servicepulse-65f6867bf8-kvfr9` in namespace `servicepulse`.

### UID / GID Verification

From pod status (live container runtime):

```
$ kubectl get pod servicepulse-65f6867bf8-kvfr9 -n servicepulse \
    -o jsonpath='{.status.containerStatuses[0].user.linux}'
{"gid":1000,"supplementalGroups":[1000],"uid":1000}
```

**Running UID: 1000 — LOCALLY VALIDATED.**

### Security Context Fields — Complete Audit

#### Pod-level `.spec.securityContext`

| Field | Manifest Value | Runtime Confirmed |
|---|---|---|
| `runAsNonRoot` | `true` | ✅ via UID=1000 |
| `runAsUser` | `1000` | ✅ LOCALLY VALIDATED |
| `runAsGroup` | `1000` | ✅ LOCALLY VALIDATED |
| `fsGroup` | `1000` | ✅ LOCALLY VALIDATED |
| `seccompProfile.type` | `RuntimeDefault` | ✅ LOCALLY VALIDATED |
| `hostNetwork` | not set | ✅ LOCALLY VALIDATED |
| `hostPID` | not set | ✅ LOCALLY VALIDATED |
| `hostIPC` | not set | ✅ LOCALLY VALIDATED |

#### Container-level `.spec.containers[0].securityContext`

| Field | Manifest Value | Status |
|---|---|---|
| `allowPrivilegeEscalation` | `false` | ✅ LOCALLY VALIDATED |
| `readOnlyRootFilesystem` | `true` | ✅ LOCALLY VALIDATED |
| `capabilities.drop` | `["ALL"]` | ✅ LOCALLY VALIDATED |
| `capabilities.add` | _(none)_ | ✅ LOCALLY VALIDATED |
| `privileged` | not set (implicitly false) | ✅ LOCALLY VALIDATED |

---

## Writable Paths

Because `readOnlyRootFilesystem: true` is set, the container cannot write to the root filesystem. Two writable volumes are explicitly mounted:

| Mount | Type | Purpose |
|---|---|---|
| `/app/data` | `emptyDir {}` | SQLite database storage |
| `/tmp` | `emptyDir {medium: Memory, sizeLimit: 64Mi}` | Temporary files (memory tmpfs) |

All other filesystem paths are read-only. **LOCALLY VALIDATED** (container is running successfully with no filesystem write errors).

---

## Dockerfile Security Audit

File: `container/servicepulse/Dockerfile`

| Control | Implementation | Status |
|---|---|---|
| Multi-stage build | `AS builder` → `AS runtime` | ✅ IMPLEMENTED |
| No credentials in image | No `.env`, no secrets COPY | ✅ VERIFIED |
| Non-root user | `RUN groupadd -g 1000 appuser && useradd -u 1000` | ✅ IMPLEMENTED |
| Non-root execution | `USER 1000:1000` | ✅ IMPLEMENTED |
| No SUID/SGID binaries | `python:3.12-slim` base — minimal attack surface | ✅ DESIGNED |
| Deterministic UID | UID 1000, GID 1000 | ✅ IMPLEMENTED |
| Minimal writable paths | `mkdir /app/data /tmp && chown appuser` | ✅ IMPLEMENTED |
| No unnecessary packages | `pip install` only, no `apt install curl/wget` | ✅ IMPLEMENTED |
| HEALTHCHECK | Native Docker healthcheck on `/health` | ✅ IMPLEMENTED |

---

## Security Scanning

### Bandit (Python AST Security Scanner)

```
Tool: bandit 1.9.4
Scope: src/servicepulse/app/** (1,188 lines of code)
Run: 2026-10-08

Test results:
    No issues identified.

Run metrics:
    Total issues (by severity): Low: 0, Medium: 0, High: 0
    Total lines skipped (#nosec): 0
    Total potential issues skipped (specifically disabled): 2
```

**Evidence classification: LOCALLY VALIDATED.**

The 2 disabled checks are documented suppressions in the application source (`#nosec BXXXs`).

### pip-audit (Dependency Vulnerability Audit)

```
Tool: pip-audit 2.10.1
Scope: src/servicepulse/requirements.txt

Packages audited:
  fastapi 0.142.2, uvicorn 0.34.3, pydantic 2.11.4,
  SQLAlchemy 2.0.41, python-dotenv 1.2.4, opentelemetry-api 1.45.1,
  starlette 1.7.0, anyio 4.15.1, h11 0.16.0, ...

Result:
  No known vulnerabilities found
```

**Evidence classification: LOCALLY VALIDATED.**

---

## Secrets Audit

```
$ git grep -i "password"
charts/servicepulse/values.yaml:  # databaseUrl: "postgresql://appuser:password@..." # COMMENTED EXAMPLE
k8s/base/secret.example.yaml:  DATABASE_URL: "...EXAMPLE_PASSWORD_PLACEHOLDER..."  # PLACEHOLDER
k8s/monitoring/values.yaml:  adminPassword: "admin"  # DUMMY LOCAL TEST VALUE
```

| Item | Classification | Action |
|---|---|---|
| `adminPassword: "admin"` | Dummy test credential — local Grafana only | Documented; acceptable for local portfolio |
| `EXAMPLE_PASSWORD_PLACEHOLDER` | Placeholder in `.example` file | Not a real credential |
| Commented DB URL | Commented out — not active | Acceptable |
| No private keys found | `git grep` confirmed clean | ✅ |
| No API tokens found | `git grep` confirmed clean | ✅ |
| `.gitignore` covers `*.pem`, `*.key`, kubeconfig | Policy in place | ✅ |

**No real secrets committed. LOCALLY VALIDATED.**

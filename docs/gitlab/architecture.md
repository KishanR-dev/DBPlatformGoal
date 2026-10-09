# GitLab CI/CD Pipeline Architecture

## Overview
The `DBPlatformGoal` project utilizes GitLab CI/CD to orchestrate an end-to-end continuous integration and delivery pipeline. This mechanism codifies the build, security, packaging, deployment, and live verification criteria required by DB Engineering & Consulting GmbH standards into a deterministic sequence of events.

## CI/CD Strategy
The pipeline is hosted on **GitLab.com** (`KishanR-dev/DBPlatformGoal`) and executed live using a registered local GitLab Runner on Ubuntu WSL2. The pipeline enforces strict gates at every stage: any failure in validation, test coverage, or security scanning immediately halts the promotion cycle.

### Stage Breakdown
The pipeline adheres to a strict 7-stage promotion model:

1. **`validate`**: Syntax correctness and static schema verification.
   - `lint:bash`: Evaluates all shell scripts (`scripts/**/*.sh`) with `shellcheck` using an ephemeral Alpine container.
   - `lint:python`: Applies `ruff` to enforce PEP-8 standards on the application codebase (`src/servicepulse`).
   - `lint:helm`: Evaluates Helm chart definitions and `values-dev.yaml` interpolation logic against Kubernetes API specifications.
2. **`test`**: Business logic assertions.
   - `test:unit`: Executes `pytest` with a mandated **85% coverage gate** threshold via `pytest-cov`, generating a machine-readable `coverage.xml` Cobertura artifact.
3. **`security`**: Vulnerability identification prior to artifact synthesis.
   - `security:bandit`: Scans the Python AST for programmatic insecurity patterns (e.g., SQL injection or weak cryptography).
   - `security:helm-lint`: Verifies that security contexts (`runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`) are rendered in Kubernetes resources.
   - `security:pip-audit`: Scans dependencies in `requirements.txt` against known CVE vulnerabilities.
   - `security:manifest-check`: Enforces Pod Security Standards across all generated Kubernetes manifests via `scripts/ci/manifest-check.py`.
4. **`build`**: Artifact generation.
   - `build:container`: Utilizes the multi-stage Dockerfile to build an immutable image tagged with the triggering Git commit (`git-$CI_COMMIT_SHORT_SHA`). Emits an OCI archive (`servicepulse-image.tar`) preserved as an artifact.
5. **`package`**: Helm artifact promotion.
   - `package:helm`: Packages the `charts/servicepulse/` artifact stream into a versioned `.tgz` tarball artifact.
6. **`deploy`**: Imperative infrastructure convergence.
   - `deploy:kind`: Sideloads the newly built container image into the local `kind` cluster (`db-platform`) via `kind load docker-image`, followed by a deterministic `helm upgrade --install` targeting the isolated `servicepulse` namespace.
7. **`verify`**: Live operational validation.
   - `verify:health`: Asserts that `kubectl rollout status` completes cleanly within 120 seconds, followed by automated smoke tests verifying the `/health` and `/api/v1/metrics` endpoints.

## Pipeline Run Results (Evidence)

| Pipeline ID | Commit | Branch | Duration | Status | Key Milestones |
|-------------|--------|--------|----------|--------|----------------|
| **#2928691505** (IID 9) | `cc92e67` | `main` | 243s | **SUCCESS** | All 12 jobs across 7 stages passed. ServicePulse successfully deployed to `kind` with image `dbplatform/servicepulse:git-cc92e67e`. |

### Execution Artifacts
- **Coverage Report:** Extracted to `src/servicepulse/coverage.xml` and uploaded to GitLab CI Cobertura visualization.
- **Container Image Archive:** Saved to `container/servicepulse/servicepulse-image.tar` (expires in 1 hr).
- **Helm Package:** Distributed to `charts/dist/servicepulse-0.1.0.tgz` (expires in 1 day).
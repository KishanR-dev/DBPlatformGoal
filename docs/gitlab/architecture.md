# GitLab CI/CD Pipeline Architecture
## Overview
The `DBPlatformGoal` project utilizes GitLab CI/CD to orchestrate an end-to-end continuous integration and delivery pipeline. This mechanism codifies the build, security, packaging, and validation criteria required by DB E&C standards into a deterministic sequence of events.

## CI/CD Strategy
Given the context of a locally validated platform portfolio without standing authenticated external cloud providers (like GitLab.com shared runners interfacing with EKS/GKE), the pipeline is defined natively within `.gitlab-ci.yml` but validated utilizing a controlled local runner strategy.

### Stage Breakdown
The pipeline adheres to a strict 7-stage promotion model:

1. **`validate`**: Syntax correctness and static schema verification.
   - `lint:python`: Applies `ruff` to enforce PEP-8 standards.
   - `lint:helm`: Evaluates Helm chart definitions and `values-dev.yaml` interpolation logic natively against the API specifications.
2. **`test`**: Business logic assertions.
   - `test:unit`: Executes `pytest` with a mandated 85% coverage gate threshold via `pytest-cov`, generating a machine-readable `coverage.xml`.
3. **`security`**: Vulnerability identification prior to artifact synthesis.
   - `security:bandit`: Scans the Python AST for programmatic insecurity patterns (e.g. naive SQL injection or weak cryptography).
4. **`build`**: Artifact generation.
   - `build:container`: Utilizes the verified Multi-Stage Dockerfile bounds. Adopts an explicit, immutable image identity strategy mapping to the triggering Git commit (`git-$CI_COMMIT_SHORT_SHA`). An ephemeral OCI archive (`servicepulse-image.tar`) is emitted.
5. **`package`**: Helm artifact promotion.
   - `package:helm`: Packages the `charts/servicepulse/` artifact stream into a distributable `tgz` tarball.
6. **`deploy`**: Imperative infrastructure convergence.
   - `deploy:kind`: Sideloads the newly baked container directly into `kind` (negating dependency on an external Container Registry), followed by a deterministic `helm upgrade --install` targeting the isolated `servicepulse` namespace.
7. **`verify`**: Live operational validation.
   - `verify:health`: Asserts that `kubernetes rollout status` tracks to zero unavailability. Followed by a network smoke-test pinging `/health` and `/api/v1/metrics`.

## Local Runner Validation Mechanism
While standard enterprise GitLab utilizes isolated `docker` executors leveraging DinD (Docker-in-Docker), simulating this reliably locally via nested hypervisors (WSL running Docker interacting with Kind) requires exposing significant privileges.

Consequently, we have engineered `scripts/ci/local-ci-exec.sh` to deterministically emulate the GitLab CI bounded stages natively on the host execution context, asserting functionality exactly as specified without compromising isolation.
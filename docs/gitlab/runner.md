# Local Execution Guide

## Validating `.gitlab-ci.yml` Locally
Because external GitLab environments (and isolated Docker-in-Docker executors) are not authenticated in this portfolio context, validation is executed by faithfully emulating the pipeline commands locally using the system's runtime tools (Python, Helm, Docker, kubectl).

### 1. Prerequisites
- Docker Engine / Docker Desktop (Active)
- Local `kind` cluster named `db-platform` running.
- Python 3.12+ (accessible via `python3`)

### 2. Execution Command
A strict, isolated Bash emulator intercepts the logic blocks from the CI pipeline config:
```bash
# Execute from repo root
./scripts/ci/local-ci-exec.sh
```

### 3. Pipeline Differences (Local vs Native GitLab)
- **Executor Context:** Natively, GitLab CI spins up distinct isolated Pods/Containers per pipeline stage, parsing the `image: ` declaration to define context. The emulator executes directly within the current host (WSL2), injecting a local Python Virtual Environment (`venv`) to sandbox Python tasks rather than pulling distinct runner images.
- **Artifact Propagation:** Natively, `paths:` blocks are automatically zipped and unzipped across stages. The local script avoids this overhead by simply reusing the physical repository bounds.
- **Image Storing:** Built containers in GitLab would normally utilize `docker login` and push to a registry (`nexus`, `gcr`, or `gitlab registry`). The local mockup saves the local image cache explicitly into an archive and side-loads it into `kind`.
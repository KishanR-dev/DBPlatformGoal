# GitLab Runner Architecture & Execution

## Overview
As part of Phase 14B of the DB Platform delivery, the platform utilizes a **live GitLab repository** (`gitlab.com/KishanR-dev/DBPlatformGoal`) paired with a **Self-Hosted GitLab Runner** running locally within the WSL2 environment. This establishes a fully authentic CI/CD loop that executes the exact pipeline definitions configured in `.gitlab-ci.yml`.

## Local Runner Strategy

While enterprise GitLab environments utilize isolated `docker` executors leveraging DinD (Docker-in-Docker) or Kubernetes scaling, executing a seamless integration via WSL2 and Docker Desktop introduces unique bind-mount incompatibilities (`-v $CI_PROJECT_DIR:/builds/project`) due to path resolution cross-boundaries. 

To resolve this seamlessly while retaining the integrity of a real GitLab CI pipeline, the runner runs as a **Shell Executor** (`executor = "shell"`) natively on WSL2.

### 1. The Ephemeral Container Pattern
Instead of utilizing GitLab's native `image:` directives (which require Docker execution contexts and volume mounts), the pipeline injects an **ephemeral inline build pattern** directly within the `script` block.

```bash
docker build -t gitlab-ci-shellcheck -f - . << 'DB'
FROM alpine:latest
RUN apk add --no-cache shellcheck
WORKDIR /builds/project
COPY . .
CMD ["/bin/sh", "-c", "shellcheck scripts/ci/*.sh scripts/ops/*.sh"]
DB
docker run --rm gitlab-ci-shellcheck
```
This elegantly sidesteps the volume mount dilemma by copying the Git workspace directly into the container during the build step, executing the tools (like `shellcheck`, `pytest`, `helm`, `pip-audit`), and tearing down the container, preserving a clean execution environment.

### 2. Environment Configuration & Subshell Fixes
A known edge case with Debian/Ubuntu-based WSL environments operating non-interactive shell sessions (triggered by `gitlab-runner`) revolves around the `~/.bash_logout` script executing `/usr/bin/clear_console`. This command generates an `exit status 1` failure globally when there's no TTY attached.

**Fix Applied:** The `.bash_logout` file in the runner execution path was neutralized (`mv ~/.bash_logout ~/.bash_logout.bak`) ensuring clean non-interactive pipeline invocation.

### 3. Verification & Execution Status
The self-hosted Shell runner (`system ID: s_52f570c5ce0e`) polling the project successfully completed the entire 7-stage promotion model.
- **Pipeline #2928691505 (IID 9)**: Successfully executed across `validate`, `test`, `security`, `build`, `package`, `deploy`, and `verify` stages in 4 minutes (243s).
- Artifacts generated (e.g., test coverage XML, container `.tar`, Helm `.tgz`) correctly passed through the runner execution contexts.
- Downstream smoke tests reliably pinged the Helm deployment exposed within the local `kind` cluster.
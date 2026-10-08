# Environment & Toolchain Readiness Report

**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Job Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Execution Context:** Ubuntu 26.04.1 LTS inside WSL2 on Windows 10 Pro  
**Date:** 2025-10-08  
**Phase:** Toolchain Setup Only. No infrastructure or portfolio code created.

---

## 1. Machine & Host Context

| Component | Value | Notes |
|---|---|---|
| **Host OS** | Windows 10 Pro 26H2 (Build 26300) | 64-bit |
| **CPU** | Intel Core i7-8750H @ 2.20GHz | 6 cores / 12 logical processors |
| **Total Physical RAM** | 32 GB (34.19 GB detected) | Host baseline |
| **Virtualization** | Enabled (Hypervisor active) | VirtualMachinePlatform enabled |
| **WSL Version** | WSL 2.7.13.0 | Kernel 6.18.33.2-microsoft-standard-WSL2 |
| **WSL Distribution** | Ubuntu 26.04.1 LTS ("resolute") | Default user: `kr` |
| **WSL Memory Exposure** | 15.54 GiB total (12 GiB free at audit) | Within WSL container |
| **Disk Space (WSL root)** | 954 GB available / 1007 GB total (1% used) | `/dev/sde` |
| **Disk Space (Drive E:)** | 392 GB available / 1.3 TB total (69% used) | Portfolio drive |

---

## 2. Verified Toolchain

All tools are installed in Ubuntu WSL2 and callable from standard user sessions.

| Tool | Version | Executable Path | Installation Method | Verification Output |
|---|---|---|---|---|
| **Git** | `2.53.0` | `/usr/bin/git` | Ubuntu base system | `git version 2.53.0` |
| **Docker (Client)** | `29.8.2` (API 1.56) | `/usr/local/bin/docker` | Symlink to Docker Desktop WSL mount | Client + Server connected |
| **Docker (Engine)** | `29.8.2` (API 1.56) | Docker Desktop 4.94.0 | Docker Desktop WSL2 engine | 12 CPUs, 15.54 GiB RAM exposed |
| **kubectl** | `v1.36.1` | `/usr/local/bin/kubectl` | Symlink from Docker Desktop CLI tools | Kustomize v5.8.1 |
| **kind** | `v0.29.0` | `/usr/local/bin/kind` | Official upstream binary (`kind.sigs.k8s.io`) | `kind v0.29.0 go1.24.2 linux/amd64` |
| **Helm** | `v3.17.1` | `/usr/local/bin/helm` | Official upstream archive (`get.helm.sh`) | `v3.17.1 (GitCommit: 980d8ac)` |
| **Terraform** | `v1.11.1` | `/usr/local/bin/terraform` | Official HashiCorp archive (`releases.hashicorp.com`) | `Terraform v1.11.1 on linux_amd64` |
| **GitLab Runner** | `17.9.0` | `/usr/local/bin/gitlab-runner` | Official GitLab S3 binary (`gitlab-runner-downloads`) | `Version: 17.9.0 (GitCommit: c4cbe9dd)` |
| **glab** | `1.53.0` | `/usr/bin/glab` | Ubuntu 26.04 official package (`glab`) | `Current glab version: 1.53.0` |

---

## 3. Kubernetes Readiness (Without Cluster)

| Check | Result | Detail |
|---|---|---|
| **Docker daemon connectivity** | ✅ VERIFIED | `docker info` succeeds from WSL; 12 CPUs, 15.54 GiB exposed |
| **kind executable** | ✅ VERIFIED | `kind v0.29.0` operational in PATH |
| **kubectl executable** | ✅ VERIFIED | `kubectl v1.36.1` operational in PATH |
| **kind clusters existing** | ✅ NONE | `kind get clusters` returned: `No kind clusters found.` |
| **kubectl contexts existing** | ✅ NONE | `kubectl config get-contexts` returned empty context list |
| **Conflicting runtimes** | ✅ NONE | `minikube`: not present; `k3s`: not present; `microk8s`: not present |
| **Cluster created in this phase?** | ❌ **NO** | Zero clusters created. Environment readiness only. |

---

## 4. GitLab CI/CD Readiness

| Check | Result | Detail |
|---|---|---|
| **GitLab Runner installed** | ✅ YES | v17.9.0 binary installed at `/usr/local/bin/gitlab-runner` |
| **GitLab Runner registered** | ❌ NO | Unregistered; registration token from GitLab.com required in future phase |
| **glab CLI installed** | ✅ YES | v1.53.0 installed at `/usr/bin/glab` |
| **glab authentication** | ❌ NOT AUTHENTICATED | `glab auth status`: `401 Unauthorized` (no token configured; expected) |
| **Secrets/Credentials** | ✅ CLEAN | No tokens, passwords, or SSH keys present or leaked in WSL environment |

---

## 5. Security Hygiene Findings

1. **Git credentials:** No credential helper configured inside Ubuntu WSL2 (`git config --get credential.helper` returned empty). No plaintext credentials file (`~/.git-credentials`) present in WSL.
2. **Binary permissions:** All installed binaries in `/usr/local/bin` have `755` (`-rwxr-xr-x`) permissions owned by `root`. Non-root users can execute; only root can modify.
3. **Docker socket access:** Docker Desktop's proxy socket (`/mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock`) permissions are set to allow the WSL user `kr` to execute Docker commands without root escalation.
4. **SSH keys:** `~/.ssh` directory does not exist inside Ubuntu WSL. No private keys present.
5. **GitLab tokens:** Zero tokens configured.

---

## 6. Known Resource Constraints

- **Host RAM:** 32 GB total.
- **Docker/WSL RAM:** Approximately 15.54 GiB allocated to Docker Desktop/WSL.
- **Feasibility:** Single-node kind cluster + ServicePulse + Prometheus/Grafana will comfortably fit within the 15.54 GiB allocation (estimated combined footprint: 2.5–3.5 GiB). Simultaneous heavy CI compilation jobs may push memory usage higher; resource limits in k8s manifests will prevent OOM conditions.
- **Disk:** 954 GB available on WSL root filesystem; 392 GB available on Drive E:. Ample for container images, layers, and build artifacts.

---

## 7. WiproGoal Integrity Check

- **Location:** `E:\Projects\VSCode\PostOmniroute\WiproGoal\`
- **Status:** **UNTOUCHED.** Verified read-only throughout this entire phase.
- **Git HEAD:** `62edfdc` (unchanged).

---

## 8. Failures & Recovery Actions

| Failure | Detection | Root Cause | Fix Applied | Regression Test Result |
|---|---|---|---|---|
| `docker.io` apt conflict during initial kind install | Observed via `docker version` reporting Engine `29.1.3-0ubuntu4.1` instead of Docker Desktop's `29.8.2` | Ubuntu apt package for `kind` declares `Depends: docker.io`, pulling an in-WSL Docker daemon that displaced Docker Desktop | Purged `docker.io` and apt-kind with `apt-get purge -y kind docker.io && apt-get autoremove -y`. Downloaded official standalone Go binary of kind (`v0.29.0`) from `kind.sigs.k8s.io` and installed to `/usr/local/bin/kind` | `docker version` confirmed restored to Docker Desktop 29.8.2; `kind version` confirmed `v0.29.0`; `docker ps` verified clean |

---

## 9. Recommended Next Step

**ONE step only:**

> **Initialize the Git repository in `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal\`, establish a root `.gitignore`, and commit this toolchain documentation as the first baseline commit.**

No clusters, no manifests, no Terraform state, and no GitLab pipelines should be created until the repository baseline is committed and branching strategy is documented.

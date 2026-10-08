# Bash Scripting, Automation Standards & Quality Guide

**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Job Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Phase:** Phase 11 — Linux Platform Operations & Troubleshooting Lab  
**Status:** Implemented & Locally Validated  

---

## 1. Automation Standards & Principles

In modern DevOps and Platform Engineering, shell scripts are first-class software components. Poorly structured shell scripts cause catastrophic silent failures, unhandled error propagation, and security vulnerabilities.

All Bash scripts across `DBPlatformGoal` adhere to strict engineering standards:

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                           BASH ENGINEERING STANDARDS                             │
├──────────────────────────────────────────────────────────────────────────────────┤
│ 1. Strict Error Handling   : set -euo pipefail on line 2                         │
│ 2. Parameter Quoting       : Double-quote all variable expansions "$var"         │
│ 3. Static Code Analysis    : 100% ShellCheck clean (0 warnings / 0 errors)       │
│ 4. Deterministic Exits     : Strict semantic exit codes (0, 1, 2)                │
│ 5. Safe Temporary Files    : mktemp with trap 'rm -f "$TMP"' EXIT INT TERM       │
│ 6. Observability & Logging : Formatted ANSI output + structured JSON emission    │
│ 7. Idempotence & Recovery  : Zero permanent system drift across executions       │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Defensive Scripting Patterns

### 2.1 The Strict Mode Header (`set -euo pipefail`)

Every script begins with the canonical strict mode configuration:

```bash
#!/bin/bash
set -euo pipefail
```

- **`-e` (`errexit`):** Immediately exits the script if any command returns a non-zero exit status, preventing cascading failures.
- **`-u` (`nounset`):** Treats unset or uninitialized variables as an immediate error rather than expanding them to empty strings (preventing bugs like `rm -rf "$UNSET_DIR/*"`).
- **`-o pipefail`:** Prevents errors in pipelines from being masked. The return code of a pipeline becomes the exit code of the last failing command rather than defaulting to the exit code of the final command.

### 2.2 CLI Argument Handling & Option Parsing

Scripts use structured `while [[ $# -gt 0 ]]` loops with `case` statements, providing standardized `--help`, input validation, and flag handling:

```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --human)   OUTPUT_MODE="human"; shift ;;
        --json)    OUTPUT_MODE="json"; shift ;;
        --verbose) VERBOSE=true; shift ;;
        -h|--help) print_usage; exit 0 ;;
        *)         echo "Error: Unknown option '$1'" >&2; exit 2 ;;
    esac
done
```

### 2.3 Semantic Exit Code Conventions

| Exit Code | Semantic Meaning | Usage in Platform Lab |
|---|---|---|
| **`0`** | **SUCCESS** | Script completed successfully, all health checks passed within thresholds. |
| **`1`** | **OPERATIONAL WARNING / FAILURE** | Threshold exceeded (e.g. Memory $>85\%$), service unreachable, test failure. |
| **`2`** | **USAGE / SYNTAX / DEPENDENCY ERROR** | Invalid CLI flags, missing arguments, required tool (e.g. `docker`) not found. |

---

## 3. Structured Output & Machine-Readability

To enable downstream automation and programmatic integration, core diagnostic scripts support dual-mode output:

```bash
# 1. Human-Readable Mode (Default)
./scripts/ops/system-health.sh --human

# 2. Machine-Readable Structured JSON Mode
./scripts/ops/system-health.sh --json
```

### Sample JSON Output Schema (`system-health.sh --json`):

```json
{
  "status": "OK",
  "timestamp_utc": "2026-10-08T12:03:25Z",
  "system": {
    "hostname": "DESKTOP-DP7RBSE",
    "os": "Ubuntu 26.04.1 LTS",
    "kernel": "6.18.33.2-microsoft-standard-WSL2",
    "architecture": "x86_64",
    "uptime": "up 5 hours, 41 minutes",
    "load_average": {
      "1m": 1.34,
      "5m": 0.82,
      "15m": 0.68
    }
  },
  "cpu": {
    "model": "Intel(R) Core(TM) i7-8750H CPU @ 2.20GHz",
    "cores": 12
  },
  "memory": {
    "total_mib": 15912,
    "used_mib": 2769,
    "free_mib": 6922,
    "available_mib": 13142,
    "used_percent": 17,
    "swap_total_mib": 4096,
    "swap_used_mib": 0
  },
  "storage": {
    "root_mount": "/",
    "total_gb": 1007,
    "used_gb": 3,
    "available_gb": 953,
    "used_percent": 1
  },
  "network": {
    "primary_interface": "eth0",
    "primary_ip": "172.26.80.78",
    "default_gateway": "172.26.80.1",
    "dns_servers": [
      "10.255.255.254"
    ],
    "listening_ports": {
      "tcp_listeners": 5,
      "udp_listeners": 7
    }
  },
  "processes": {
    "total_count": 46
  }
}
```

---

## 4. Static Code Analysis & ShellCheck Validation

All shell scripts in the repository are validated automatically via `scripts/ops/validate-scripts.sh` and through the GitLab CI pipeline (`lint:bash` stage) using `koalaman/shellcheck:stable`:

```bash
bash scripts/ops/validate-scripts.sh
```

### Static Analysis Results:

```text
========================================================================
  DBPlatformGoal — Shell Automation Quality & Static Analysis
========================================================================
Scanning repository for shell scripts (*.sh)...

Found 9 shell scripts to validate:
  - scripts/ci/local-ci-exec.sh
  - scripts/ops/firewall-check.sh
  - scripts/ops/incident-check.sh
  - scripts/ops/network-diagnostics.sh
  - scripts/ops/process-diagnostics.sh
  - scripts/ops/resource-diagnostics.sh
  - scripts/ops/service-check.sh
  - scripts/ops/system-health.sh
  - scripts/ops/validate-scripts.sh

1. BASH SYNTAX VERIFICATION (bash -n):
  Checking syntax: scripts/ci/local-ci-exec.sh ... PASSED
  Checking syntax: scripts/ops/firewall-check.sh ... PASSED
  Checking syntax: scripts/ops/incident-check.sh ... PASSED
  Checking syntax: scripts/ops/network-diagnostics.sh ... PASSED
  Checking syntax: scripts/ops/process-diagnostics.sh ... PASSED
  Checking syntax: scripts/ops/resource-diagnostics.sh ... PASSED
  Checking syntax: scripts/ops/service-check.sh ... PASSED
  Checking syntax: scripts/ops/system-health.sh ... PASSED
  Checking syntax: scripts/ops/validate-scripts.sh ... PASSED

2. STATIC ANALYSIS VIA SHELLCHECK (koalaman/shellcheck:stable):
  Linting: scripts/ci/local-ci-exec.sh ... CLEAN (0 warnings)
  Linting: scripts/ops/firewall-check.sh ... CLEAN (0 warnings)
  Linting: scripts/ops/incident-check.sh ... CLEAN (0 warnings)
  Linting: scripts/ops/network-diagnostics.sh ... CLEAN (0 warnings)
  Linting: scripts/ops/process-diagnostics.sh ... CLEAN (0 warnings)
  Linting: scripts/ops/resource-diagnostics.sh ... CLEAN (0 warnings)
  Linting: scripts/ops/service-check.sh ... CLEAN (0 warnings)
  Linting: scripts/ops/system-health.sh ... CLEAN (0 warnings)
  Linting: scripts/ops/validate-scripts.sh ... CLEAN (0 warnings)

========================================================================
✓ ALL SHELL SCRIPTS PASSED SYNTAX & SHELLCHECK VALIDATION.
========================================================================
```

---

## 5. Complete Script Inventory & Functional Specifications

| Script Path | Purpose | Key Commands Used | Output Formats |
|---|---|---|---|
| `scripts/ops/system-health.sh` | Platform health check & subsystem metrics inspection | `uname`, `lscpu`, `free`, `df`, `ip`, `ss`, `ps` | Human / JSON |
| `scripts/ops/process-diagnostics.sh` | Deep process inspection, threads, FDs & limits | `pgrep`, `ps`, `/proc/<pid>/status`, `/proc/<pid>/limits` | Human text |
| `scripts/ops/network-diagnostics.sh` | Interface, routing, DNS, and TCP socket diagnostic suite | `ip addr`, `ip route`, `ss -tuln`, `getent`, Python sockets | Human text |
| `scripts/ops/service-check.sh` | ServicePulse & Kubernetes service reachability probe | `kubectl get svc,ep,pods`, ephemeral curl pods | Human text |
| `scripts/ops/firewall-check.sh` | Isolated Netfilter / iptables packet filtering lab | `docker run`, `iptables -A/D`, packet counters | Human text |
| `scripts/ops/resource-diagnostics.sh` | Controlled CPU/memory load analysis & recovery | Bounded Python compute, `uptime`, `free` | Human text |
| `scripts/ops/incident-check.sh` | Automated incident injection, RCA & regression harness | `kubectl patch`, ephemeral curl probes | Human text |
| `scripts/ops/validate-scripts.sh` | Bash syntax (`bash -n`) and ShellCheck quality linter | `bash -n`, Docker `koalaman/shellcheck:stable` | Human text |
| `scripts/ci/local-ci-exec.sh` | Local 7-stage CI pipeline emulation with ShellCheck & deploy | `docker`, `helm`, `kubectl`, `kind`, `pytest`, `ruff` | CI pipeline log |

# Systematic Platform Troubleshooting & Incident Analysis Methodology

**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Job Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Phase:** Phase 11 — Linux Platform Operations & Troubleshooting Lab  
**Status:** Implemented & Locally Validated  

---

## 1. The 7-Step Systematic Troubleshooting Framework

When diagnosing production platform incidents, haphazard trial-and-error changes increase outage duration and obscure root causes. The platform engineering practice follows a disciplined **7-Step Troubleshooting Framework**:

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                      7-STEP TROUBLESHOOTING FRAMEWORK                            │
├──────────────────────────────────────────────────────────────────────────────────┤
│ 1. TRIAGE         : Assess blast radius, severity, user impact, and alert scope │
│ 2. ISOLATE        : Determine the affected architectural layer (L1 to L5)       │
│ 3. REPRODUCE      : Execute deterministic probes to capture exact error codes   │
│ 4. TRACE          : Traverse the data path: Client ➔ DNS ➔ Svc ➔ EP ➔ Pod       │
│ 5. ROOT CAUSE     : Identify the physical defect or configuration discrepancy    │
│ 6. REMEDIATE      : Apply minimal, controlled corrective patch                  │
│ 7. VERIFY         : Execute automated regression smoke suite & confirm health   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Layer-by-Layer Diagnostic Matrix

```text
                                  ┌────────────────────────┐
                                  │   Incident Reported    │
                                  └───────────┬────────────┘
                                              │
                                              ▼
                             ┌─────────────────────────────────┐
                             │ Is DNS Resolution Working?     │
                             └────────┬───────────────┬────────┘
                                  YES │               │ NO
                                      │               ▼
                                      │   Inspect /etc/resolv.conf,
                                      │   systemd-resolved, CoreDNS
                                      │
                                      ▼
                             ┌─────────────────────────────────┐
                             │ Does TCP Handshake Connect?    │
                             └────────┬───────────────┬────────┘
                                  YES │               │ NO
                                      │               ▼
                                      │   Inspect ss -tuln, iptables,
                                      │   Kubernetes Service & Endpoints
                                      │
                                      ▼
                             ┌─────────────────────────────────┐
                             │ Does HTTP Request Return 200?   │
                             └────────┬───────────────┬────────┘
                                  YES │               │ NO
                                      │               ▼
                                      │   Inspect Application Logs,
                                      │   Database connection, SQLite
                                      │
                                      ▼
                             ┌─────────────────────────────────┐
                             │ Performance & Latency Acceptable│
                             └────────┬───────────────┬────────┘
                                  YES │               │ NO
                                      │               ▼
                                      │   Inspect CPU load, Memory RSS,
                                      │   I/O wait, Prometheus metrics
                                      ▼
                             ┌─────────────────────────────────┐
                             │ System Operating in Green State │
                             └─────────────────────────────────┘
```

---

## 3. Symptoms-to-Diagnostics Mapping Table

| Symptom / Alert | Root Cause Category | Diagnostic Commands | Script / Playbook |
|---|---|---|---|
| `curl: (6) Could not resolve host` | DNS Resolution Failure | `getent ahosts <domain>`, `cat /etc/resolv.conf`, `kubectl logs -n kube-system -l k8s-app=kube-dns` | `scripts/ops/network-diagnostics.sh` |
| `curl: (7) Failed to connect` / `(28) Timeout` | Service / Port Misdirection | `kubectl get svc,ep -n <ns>`, `ss -tuln`, compare `targetPort` vs `containerPort` | `scripts/ops/incident-check.sh` |
| `HTTP 500 Internal Server Error` | Application / Database Crash | `kubectl logs <pod> -n <ns> --tail=100`, inspect SQLite database lock | `scripts/ops/service-check.sh` |
| `CrashLoopBackOff` | Startup Failure / Failed Probe | `kubectl describe pod <pod> -n <ns>`, check exit code (e.g. 137 OOM, 1 Exception) | `docs/operations/runbook.md` (Playbook 2) |
| High CPU Load / Sluggishness | CPU Saturation / Runaway Thread | `uptime`, `lscpu`, `ps -eo pid,user,%cpu,%mem,stat,comm --sort=-%cpu` | `scripts/ops/process-diagnostics.sh` |
| Container Exit Code 137 | OOMKilled by Kernel | `free -m`, `kubectl describe pod` (`Last State: Terminated, Reason: OOMKilled`) | `scripts/ops/resource-diagnostics.sh` |
| Packet Loss / Connection Drops | Firewall Drop Rule Active | `iptables -L INPUT -v -n --line-numbers`, inspect drop counters | `scripts/ops/firewall-check.sh` |

---

## 4. Common Troubleshooting Anti-Patterns

1. **Restarting Pods Blindly:** Restarting a failing pod destroys ephemeral `/tmp` state, crash logs, and process states before diagnostic information can be captured. *Always capture `kubectl logs --previous` and `kubectl describe pod` before modifying resources.*
2. **Editing Live Cluster Manifests Without Version Control:** Applying ad-hoc `kubectl edit` patches without committing changes to Helm `values.yaml` or manifests leads to immediate configuration drift upon the next CI/CD deployment.
3. **Assuming Host and Pod Networks are Identical:** Attempting to query `localhost:8000` from the host OS when the service is bound to a Pod IP inside an isolated container network namespace.
4. **Confusing NetworkPolicy with Firewall:** Expecting Kubernetes NetworkPolicy manifests to enforce packet filtering on a CNI (such as `kindnetd`) that lacks an enforcing data plane engine.

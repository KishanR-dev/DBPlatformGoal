# Operations Incident Playbook

This document captures a validated controlled incident, evidencing observability-led correlation tracing and root-cause verification using locally running Prometheus metrics and Kubernetes logs.

## Scenario: Catastrophic Deployment Termination

### 1. Detection
- **Grafana Panel Signature:** The "API Target Status" transitions deeply to `DOWN`. Simultaneous flatlining of the "HTTP Request Rate". "Pod Restarts" (or missing metrics entirely) illustrate an immediate drop-off state.
- **Symptom:** Operations can identify this is a definitive catastrophic termination, not an escalating application lag.

### 2. Injection Command (Simulated Root Cause)
Deliberately scaling down the workload triggers the event:
```bash
> kubectl scale deployment servicepulse -n servicepulse --replicas=0
deployment.apps/servicepulse scaled
```

### 3. Investigation Trace
- **Prometheus Verification:** ServiceMonitor target immediately vanishes or enters a DOWN/Unreachable scrape status.
- **Cluster Diagnostics:**
```bash
> kubectl get pods -n servicepulse
No resources found in servicepulse namespace.
```

### 4. Correlation
The dashboard confirms the state change, dropping metrics gracefully and indicating complete offline failure. The metrics confirm the deployment engine intentionally reaped the instances. 

### 5. Resolution & Recovery
```bash
> kubectl scale deployment servicepulse -n servicepulse --replicas=1
deployment.apps/servicepulse scaled
```

### 6. Validation
- **Phase transition:** Pod spins to `Running`.
- **Telemetry transition:** Within $< 15\text{s}$, Prometheus re-acquires the ServiceMonitor endpoint. Grafana transitions target state back to `UP`.
- **Load validation:** Synthetically injecting traffic demonstrates proper resumption of Request Rate and Latency tracking metrics.

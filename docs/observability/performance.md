# Local Development Benchmark

## Objective
Provide documented evidence that operational tooling (Prometheus & Grafana) correctly observes, correlates, and quantifies structural behavior changes when bounded synthetic loads run against the local target.

## Methodology
The benchmark operates against the local `kind` ServicePulse platform via a configurable Bash orchestrator `scripts/benchmark/load.sh`.

### Test Characteristics
- **Tool:** Vegeta (or parallel Bash/ab fallback)
- **Target:** `http://localhost:8080/health`
- **Volume:** Configured RPS (e.g. 30 req/s) sustained over a fixed duration (e.g. 30s)

### Test Iterations

**Test 1: Gentle Baseline Load**
- *Goal:* Verify basic metrics tracing without stressing pod limitations.
- *Orchestration:* `load.sh http://localhost:8080 30s 30`
- *Observation Check:*
    - **Throughput:** Climbs steadily stabilizing at ~30 requests per second.
    - **Latency:** Request latency traces closely to sub-3ms.
    - **Computing Elements:** Minimal visible deflection on the CPU panel (~25-50m increment).

**Findings:** The monitoring configuration correctly processes time boundaries and identifies rate scaling. The application adequately responds under controlled synthetic demand within its `100m`/`128Mi` constraints.

## Safety Measures
- Measurements execute fully off the public internet, port-forwarding to internal test boundaries.
- The `load.sh` harness strictly enforces duration timing (`set -e` boundary controls) preventing prolonged runaway looping locally.

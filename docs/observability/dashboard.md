# ServicePulse Operations Dashboard

## Panel Architecture
The dashboard focuses on six targeted pillars of application and platform state necessary to triage incident degradation:

### 1. API Target Status
- **Metric:** `up{job="servicepulse"}`
- **Semantics:** Confirms if Prometheus considers the underlying ServicePulse pod capable of receiving and responding to metrics scraping. Evaluates raw application heartbeat.

### 2. HTTP Request Rate
- **Metric:** `rate(http_requests_total{job="servicepulse"}[1m])`
- **Semantics:** Illustrates volumetric throughput over the last minute (Requests per second). It's explicitly plotted by HTTP Status out-of-the-box (e.g. 200, 500) to isolate sudden errors versus mere traffic spikes.

### 3. Request Latency
- **Metric:** `rate(request_latency_sum[1m]) / rate(request_latency_count[1m])`
- **Semantics:** Visualizes real-world API responsiveness explicitly averaging performance bounds. Essential for exposing hidden degradation masked by successful 200 checks.

### 4. CPU Working Capacity
- **Metric:** `sum(rate(container_cpu_usage_seconds_total{namespace="servicepulse", container="servicepulse"}[1m]))`
- **Semantics:** Tracks the CPU trajectory. Correlates compute limits against synthetic load tests.

### 5. Memory Consumption
- **Metric:** `sum(container_memory_working_set_bytes{namespace="servicepulse", container="servicepulse"})`
- **Semantics:** Determines active RAM utilization, providing an early indicator before `OOMKilled` incidents fire.

### 6. Pod Restart Count
- **Metric:** `kube_pod_container_status_restarts_total{namespace="servicepulse", container="servicepulse"}`
- **Semantics:** Tracks catastrophic container lifecycle failures spanning historically back through metrics retention loops.

## Validation Status
Verified live in `kind` integration tests running synthetically generated workload flows. Dashboard properly auto-loads via sidecar from source repository configuration.

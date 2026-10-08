# Prometheus Implementation & Validation

## Scrape Configuration
Prometheus targets are managed through the Prometheus Operator using `ServiceMonitor` definitions. Ensure Prometheus is permitted to read `ServiceMonitor` resources across namespaces via `serviceMonitorSelector: {}` in the Helm values.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: servicepulse
  namespace: servicepulse
  labels:
    app.kubernetes.io/name: servicepulse
    app.kubernetes.io/component: backend
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: servicepulse
  endpoints:
    - port: http
      path: /api/v1/metrics
      interval: 15s
  namespaceSelector:
    matchNames:
      - servicepulse
```

## Validation Evidence

### Target Discovery
```bash
> curl -s "http://localhost:9090/api/v1/targets" | jq .
"__meta_kubernetes_endpoint_address_target_name": "servicepulse-65f6867bf8-kvfr9"
"__meta_kubernetes_namespace": "servicepulse"
"health": "up"
"lastScrapeDuration": 0.008178231
```
The ServicePulse pod is correctly identified, and the target health consistently registers as "up", proving internal network routing and endpoint configurations are valid.

### Metric Assertion
Executing a PromQL query via the API demonstrates active data ingestion:
```bash
> curl -s "http://localhost:9090/api/v1/query?query=http_requests_total"
"metric": {
    "__name__": "http_requests_total",
    "endpoint": "http",
    "exported_endpoint": "/health",
    "job": "servicepulse",
    "status": "200"
},
"value": [1791464498.601, "832"]
```
ServicePulse is correctly differentiating between its standard metrics endpoint and core health checks.

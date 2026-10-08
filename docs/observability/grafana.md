# Grafana Deployment & Configuration

## Deployment Profile
Grafana is rolled out as part of the `kube-prometheus-stack` Helm chart. The deployment focuses on operational utility, avoiding cosmetic overhead.

## Datasource Wiring
The Prometheus datasource is auto-provisioned securely by the Operator. Connections do not pass over the public internet, utilizing native Kubernetes DNS routing (`http://kube-prometheus-stack-prometheus.monitoring:9090`).

## Dashboard-as-Code Strategy
Grafana is instrumented using the sidecar pattern to dynamically discover and inject JSON dashboards wrapped in Kubernetes ConfigMaps.

In `monitoring/values.yaml`:
```yaml
grafana:
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
      labelValue: "1"
      searchNamespace: ALL
```
When `servicepulse-dashboard` ConfigMap is pushed to the cluster, the sidecar recognizes the `grafana_dashboard: "1"` label and safely loads the dashboard directly into the UI without manual intervention.

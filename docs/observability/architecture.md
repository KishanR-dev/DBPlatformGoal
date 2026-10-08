# Observability Architecture

## Purpose
This document outlines the observability architecture designed for the ServicePulse DB Platform Goal, focusing on reliable metrics collection, targeted visualization, and evidence-driven operational transparency.

## Component Flow
The local kind cluster integrates the `kube-prometheus-stack` maintained by the Prometheus Community. The data path is explicitly modeled as:

`ServicePulse Endpoint (/api/v1/metrics)` $\rightarrow$ `Prometheus Scraper` $\rightarrow$ `Prometheus Time-Series Database` $\rightarrow$ `Grafana Dashboard`

- **ServicePulse:** Exposes application metrics (HTTP totals, latency distributions, custom domains) on `/api/v1/metrics`. It natively formats metrics in Prometheus exposition format.
- **ServiceMonitor (monitoring.coreos.com/v1):** The declarative bridge configuring the Prometheus Operator to discover ServicePulse endpoints labeled `app.kubernetes.io/name: servicepulse`.
- **Prometheus:** Periodically scrapes (15s interval) and stores metric values.
- **NodeExporter & Kube-State-Metrics:** Capture underlying cluster resources (CPU, Memory, Pod restarts).
- **Grafana:** Queries Prometheus using PromQL to visualize platform and application health. Dashboards are managed as code (ConfigMaps).

## Design Constraints
- **Resource Limits:** Alertmanager and persistent storage are deliberately disabled, minimizing local hardware overhead during validation.
- **Scrape Limits:** Tightened interval configurations and disabled complex Kubernetes system monitoring (e.g., etcd, coreDNS) avoid overwhelming the small cluster footprint.
- **Security & RBAC:** Operations remain inside the local cluster perimeter, only exposed via explicit localhost `kubectl port-forward` commands.

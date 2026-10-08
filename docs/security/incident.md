# Security Incident RCA — Phase 13

**Evidence Classification:** LOCALLY VALIDATED  
**Incident Type:** NetworkPolicy Misconfiguration  
**Cluster:** `db-platform-tf` (kind, Kubernetes v1.33.1)  
**CNI:** kindnet (nftables enforcement)  
**Script:** `scripts/security/incident-networkpolicy.sh`

---

## Incident Summary

| Field | Value |
|---|---|
| Severity | Medium (observability impact; no application downtime) |
| Affected component | Prometheus → ServicePulse scrape path |
| Root cause | Incorrect pod selector label in NetworkPolicy ingress rule |
| Impact | Prometheus cannot scrape `/api/v1/metrics`; Grafana panels show no data |
| Application health | ServicePulse `/health` returns 200 throughout |
| Duration (simulated) | ~10 seconds (policy propagation + detection) |
| Remediation | Restore correct NetworkPolicy from backup |

---

## Workflow

```
BASELINE
  │  Monitoring namespace can reach ServicePulse:8000
  │  curl from monitoring → HTTP 200
  ▼
FAULT INJECTION
  │  Operator applies NetworkPolicy with wrong ingress podSelector:
  │    matchLabels: { app: prometheus }  ← INCORRECT LABEL
  │  kindnet nftables installs new rules
  ▼
DETECTION
  │  curl from monitoring → EXIT 28 (timeout = packet dropped)
  │  In production: Prometheus target_up = 0, scrape fails
  ▼
INVESTIGATION
  │  kubectl describe networkpolicy servicepulse-netpol -n servicepulse
  │  → Shows ingress from app=prometheus (label mismatch visible)
  │  kubectl get pods -n monitoring --show-labels
  │  → Actual Prometheus label: app.kubernetes.io/name=prometheus
  │  kubectl get events -n servicepulse
  ▼
ROOT CAUSE
  │  Ingress allow rule used 'app=prometheus'
  │  Actual kube-prometheus-stack pods have NO such label
  │  Result: allow rule matches nothing → policy blocks all ingress
  ▼
REMEDIATION
  │  Apply correct NetworkPolicy (restored from backup)
  │  kindnet nftables updated
  ▼
REGRESSION PROOF
  │  curl from monitoring → HTTP 200 (scrape path restored)
  │  ServicePulse /health → OK (application never impacted)
```

---

## Detailed Evidence

### Step 1: Baseline

```
$ kubectl run incident-baseline \
    --image=curlimages/curl:8.6.0 \
    --namespace=monitoring --restart=Never --rm -i \
    --command -- curl -s -m 5 -o /dev/null -w "%{http_code}" \
    "http://10.244.1.2:8000/api/v1/metrics"
200
pod "incident-baseline" deleted
```

**LOCALLY VALIDATED: monitoring → servicepulse metrics: HTTP 200**

### Step 2: Fault Injection — Erroneous NetworkPolicy Applied

```yaml
# ERRONEOUS POLICY (injected for incident)
ingress:
  - from:
      - podSelector:
          matchLabels:
            app: prometheus   # WRONG: no pod in monitoring has this label
    ports:
      - protocol: TCP
        port: 8000
```

Applied:
```
$ kubectl apply -f -
networkpolicy.networking.k8s.io/servicepulse-netpol configured
```

### Step 3: Detection

```
$ kubectl run incident-after-fault \
    --image=curlimages/curl:8.6.0 \
    --namespace=monitoring --restart=Never --rm -i \
    --command -- curl -s -m 5 -o /dev/null -w "%{http_code}" \
    "http://10.244.1.2:8000/api/v1/metrics"
000   (or exit 28)
pod "incident-after-fault" deleted (Error)
```

**Packet dropped by kindnet nftables. LOCALLY VALIDATED.**

In production, this would manifest as:
- `prometheus_target_up{job="servicepulse"} = 0`
- Grafana panels blank or showing gaps
- Prometheus alert: `TargetDown`

### Step 4: Investigation

```
$ kubectl describe networkpolicy servicepulse-netpol -n servicepulse
Name:         servicepulse-netpol
Namespace:    servicepulse
PodSelector:  app=servicepulse
Allowing ingress traffic:
  To Port: 8000/TCP
  From:
    PodSelector: app=prometheus    ← VISIBLE BUG

$ kubectl get pods -n monitoring --show-labels
NAME                                       LABELS
prometheus-kube-prometheus-stack-...       app.kubernetes.io/name=prometheus   ← CORRECT LABEL
```

Label mismatch: `app=prometheus` vs `app.kubernetes.io/name=prometheus`.

### Step 5: Root Cause

The NetworkPolicy ingress rule was authored with the abbreviated label `app=prometheus`. The kube-prometheus-stack Prometheus instance does not carry that label. The correct selector is `app.kubernetes.io/name: prometheus` or `namespaceSelector: {kubernetes.io/metadata.name: monitoring}`.

Because the allow rule matched no pods, kindnet installed rules that effectively blocked all ingress to ServicePulse from the monitoring namespace.

### Step 6: Remediation

```
$ kubectl apply -f "${BACKUP_NETPOL_FILE}"
networkpolicy.networking.k8s.io/servicepulse-netpol configured
```

### Step 7: Regression Validation

```
$ kubectl run incident-after-fix \
    --image=curlimages/curl:8.6.0 \
    --namespace=monitoring --restart=Never --rm -i \
    --command -- curl -s -m 5 -o /dev/null -w "%{http_code}" \
    "http://10.244.1.2:8000/api/v1/metrics"
200
pod "incident-after-fix" deleted

$ kubectl exec servicepulse-65f6867bf8-kvfr9 -n servicepulse -- \
    python3 -c "import urllib.request,sys; r=urllib.request.urlopen('http://localhost:8000/health',timeout=5); sys.exit(0 if r.getcode()==200 else 1)"
# exit code 0
```

**LOCALLY VALIDATED: scrape path restored, application health intact.**

---

## Key Lessons Demonstrated

| Finding | Learning |
|---|---|
| NetworkPolicy pod selectors are label-exact | A missing or abbreviated label creates a silent allow-nothing rule |
| kindnet enforcement is real | Packet blocking happens at nftables layer, not just etcd |
| Application health is independent | Service can be running while observability is broken |
| Backup before changes | Policy backup enables rapid rollback |
| `kubectl describe` is the primary investigation tool | Shows exactly what selectors the policy matches |

---

## Observability Integration Note

In a production system with Prometheus/Grafana:

- Prometheus `up` metric for the servicepulse target would drop to 0
- Alert: `TargetDown` would fire within 2-3 scrape intervals (30-45s)
- Grafana: ServicePulse panels would show gaps from the moment of policy change

The Prometheus and Grafana stack deployed in Phase 12 provides this detection mechanism. The ServiceMonitor in `k8s/monitoring/servicemonitor.yaml` scrapes `/api/v1/metrics` every 15s, so an alert would fire within ~45s of the misconfiguration.

**Evidence classification: LOCALLY VALIDATED (connectivity tests), DESIGNED (Prometheus alert path in production).**

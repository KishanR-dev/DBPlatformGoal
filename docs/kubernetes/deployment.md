# Kubernetes Deployment & Operations Runbook — ServicePulse

**Document Version:** 1.0.0  
**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Target Cluster:** `db-platform` (Multi-node kind cluster)  
**Status:** Validated Operational Runbook  

---

## 1. Prerequisites & Environment

Before deploying, ensure the following verified tools are active on the host / WSL2 system:

- **Docker Desktop:** Engine `29.8.2` or later running with WSL2 integration.
- **kind:** `v0.29.0` or later (`kind version`).
- **kubectl:** `v1.36.1` or later (`kubectl version --client`).
- **Local Container Image:** `dbplatform/servicepulse:git-f549433` pre-built in Docker Desktop.

---

## 2. Step-by-Step Cluster Creation & Deployment Procedure

### Step 2.1: Bootstrap the Multi-Node kind Cluster
```bash
# Execute from DBPlatformGoal repository root
kind create cluster --config kind/cluster.yaml
```
*Expected Output:* Creates cluster `db-platform` with 1 control-plane and 2 worker nodes, setting kubectl context to `kind-db-platform`.

```bash
# Verify cluster node status
kubectl get nodes -o wide
```

### Step 2.2: Sideload the Local Container Image
Because the image is built locally on the developer host and not yet pushed to an external registry, sideload it into all kind nodes:
```bash
kind load docker-image dbplatform/servicepulse:git-f549433 --name db-platform
```

```bash
# Verify image is cached in containerd across worker nodes
docker exec db-platform-worker crictl images | grep servicepulse
docker exec db-platform-worker2 crictl images | grep servicepulse
```

### Step 2.3: Dry-Run Manifest Validation
```bash
kubectl apply --dry-run=client -k k8s/base
```

### Step 2.4: Deploy Declarative Workload Layer
```bash
kubectl apply -k k8s/base
```

### Step 2.5: Monitor Rollout & Verify Pod Readiness
```bash
kubectl rollout status deployment/servicepulse -n servicepulse --timeout=60s
kubectl get all -n servicepulse -o wide
```

---

## 3. Workload Verification & Troubleshooting Commands

### 3.1 Inspect Pod Details, Probes & Events
```bash
kubectl describe pod -n servicepulse -l app=servicepulse
```

### 3.2 Inspect Live Application Logs
```bash
kubectl logs -n servicepulse -l app=servicepulse -f
```

### 3.3 Validate In-Cluster Service DNS & Routing
```bash
kubectl run curl-test --namespace=servicepulse --image=curlimages/curl:8.12.1 \
  --restart=Never --rm -i --command -- curl -s http://servicepulse.servicepulse.svc.cluster.local:80/health
```

### 3.4 Local Port-Forwarding (Host Diagnostic Access)
```bash
kubectl port-forward -n servicepulse svc/servicepulse 8080:80
# Access in browser or curl:
# http://localhost:8080/health
# http://localhost:8080/api/v1/metrics
```

---

## 4. Controlled Failure Simulation & Recovery

### Test: Pod Deletion & Controller Self-Healing
```bash
# 1. Identify active pod
POD=$(kubectl get pod -n servicepulse -l app=servicepulse -o jsonpath="{.items[0].metadata.name}")

# 2. Delete active pod
kubectl delete pod -n servicepulse $POD

# 3. Observe deployment controller recreating replacement pod
kubectl get pods -n servicepulse -w

# 4. Confirm replacement pod reaches Ready state
kubectl rollout status deployment/servicepulse -n servicepulse
```

---

## 5. Clean Teardown & Repeatability Procedure

### 5.1 Remove Application Workload Only
```bash
kubectl delete -k k8s/base
```

### 5.2 Destroy kind Cluster
```bash
kind delete cluster --name db-platform
```
*Expected Output:* `Deleted clusters: ["db-platform"]`.

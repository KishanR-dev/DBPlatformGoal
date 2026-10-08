# Helm Release Usage Guide

## Prerequisites
- Helm v3+
- Target Kubernetes cluster (`db-platform`)
- Current Kubernetes context set correctly.

## 1. Validating the Chart
Lint the chart's syntax and types:
```bash
helm lint charts/servicepulse
```

Render templates locally against schema variables (dry-run):
```bash
helm template servicepulse charts/servicepulse -f charts/servicepulse/values-dev.yaml
```

## 2. Bootstrapping Installation
Install the Helm chart in the designated namespace:
```bash
# Provide custom values with -f to set up the Development release
helm upgrade --install servicepulse charts/servicepulse \
  --namespace servicepulse \
  --create-namespace \
  -f charts/servicepulse/values-dev.yaml
```

Check deployment rollout:
```bash
kubectl rollout status deployment/servicepulse -n servicepulse
```

## 3. Atomic Standard Upgrades
Modify properties iteratively using Helm `--set` flags or file overrides.

Example: Upgrading logging verbosity on the fly:
```bash
helm upgrade servicepulse charts/servicepulse \
  --namespace servicepulse \
  -f charts/servicepulse/values-dev.yaml \
  --set config.logLevel=DEBUG
```

Verify history and revision bump:
```bash
helm history servicepulse -n servicepulse
```

## 4. Rollback and Disaster Recovery
Roll back immediately to a stable known revision.
```bash
# Rollback to revision 1, wait until Pods become fully ready.
helm rollback servicepulse 1 --namespace servicepulse --wait
```
Confirm reversion:
```bash
helm history servicepulse -n servicepulse
```

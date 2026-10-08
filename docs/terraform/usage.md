# Terraform Infrastructure Usage

This document explains the usage and lifecycle management for the DB Platform's local Kubernetes infrastructure.

## Prerequisites

- Terraform >= 1.5.0
- Docker Desktop or a local Docker daemon
- The `tehcyx/kind` provider is dynamically fetched via `terraform init`.

## 1. Initialization

```bash
cd terraform
terraform init
```

## 2. Planning Changes

Review what Terraform intends to do (drift detection):

```bash
terraform plan
```

Overriding a variable to simulate an infrastructure upgrade:
```bash
terraform plan -var="worker_node_count=3"
```

## 3. Applying Configuration

Apply the infrastructure declaratively:

```bash
terraform apply
```

Terraform provisions the `db-platform-tf` cluster. Output includes cluster endpoints and sensitive kubeconfig attributes.

## 4. Kubernetes Boundary Handoff

After Terraform has applied successfully, the infrastructure is active.
Because of our separation of concerns, the ServicePulse Helm chart is managed externally (e.g., via GitLab CI/CD Pipeline). 

To test locally:
1. Export the context:
   ```bash
   kind export kubeconfig --name db-platform-tf
   kubectl get nodes
   ```
2. Manually load your locally-built image to the new Terraform cluster:
   ```bash
   kind load docker-image dbplatform/servicepulse:4a828f68 --name db-platform-tf
   ```
3. Run the CI script or Helm install.

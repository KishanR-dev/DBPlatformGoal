# Terraform Infrastructure Architecture

This document describes the Infrastructure as Code (IaC) architecture for the DB platform environment.

## 1. Provider Strategy

- **Provider**: `tehcyx/kind`
- **Version Constraint**: `> 0.5.0` (currently locked to `0.7.0`)
- **Reason**: We require reproducible provisioning of local Kubernetes clusters to match the target workload contracts.

## 2. Resource Ownership Boundaries

For this local delivery environment, we observe a strict separation of concerns to avoid duplication of state and unexpected lifecycle behaviors.

- **Terraform owns:** The platform infrastructure (Kubernetes cluster topology, nodes, API boundaries). 
- **Helm / GitLab CI owns:** The application payload delivery (ServicePulse Helm Chart).

Terraform stops at the cluster boundary. This confirms proper layered separation observed in professional cloud provisioning models (e.g., EKS provisioned by Terraform; workloads managed by Helm/ArgoCD).

## 3. Topologies and State Management

- The single cluster uses 1 control-plane and 2 worker nodes.
- Variables parameterize `worker_node_count` and `kubernetes_version` to demonstrate change capabilities safely.
- State is strictly excluded from version control via `.gitignore`.

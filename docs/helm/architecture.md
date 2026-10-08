# Helm Chart Architecture

## Overview
The `servicepulse` Helm chart establishes the declarative packaging standard for the ServicePulse workload on the DB Platform, shifting from raw Kubernetes manifests (via Kustomize) to a parameterized release artifact.

This design enables automated continuous deployment, value overrides across environments (dev vs. prod), and lifecycle guarantees (upgrades and rollbacks).

## Chart Structure

```text
charts/servicepulse/
├── Chart.yaml             # Ecosystem metadata (version, appVersion)
├── values.yaml            # Base default configuration
├── values-dev.yaml        # Development environment overrides
├── values-prod.yaml       # Production environment overrides
├── templates/
│   ├── _helpers.tpl       # Rendering helpers (labels, names)
│   ├── deployment.yaml    # Workload topology
│   ├── service.yaml       # In-cluster network exposure
│   ├── configmap.yaml     # Environment injection
│   └── networkpolicy.yaml # CNI isolation rules (Zero Trust boundary)
└── .helmignore            # Ignore patterns
```

## Architectural Decisions

### 1. Separation of Environments via Value Files
We decouple the declarative schema from the runtime environment. 
- `values.yaml` provides strict, secure defaults for all properties (e.g. `replicaCount: 1`).
- `values-dev.yaml` allows laxer logging and mock properties.
- `values-prod.yaml` enforces rigid production readiness (e.g., higher resource limits or specific taints).

### 2. SQLite Context Boundary (replicaCount)
The `replicaCount` defaults to `1` in all environments because ServicePulse relies on a localized SQLite WAL database (`/app/data`). Setting this over 1 without read-write-many standard storage or a decentralized RDBMS like PostgreSQL would cause database corruption or concurrency deadlocks. Horizontal scaling is intentionally gated until state migration.

### 3. Container Security Passthrough
The security context configuration maps 1:1 with DB E&C security standards:
- Rootfs is strictly read-only.
- The binary executes entirely dropped capabilities (`drop: ["ALL"]`).
- Volume mounts mapped in `values.yaml` explicitly decouple state boundaries to volatile (`/tmp`) and persistent (`/app/data`) layers.

### 4. Template Reusability
Standard label blocks (`helm.sh/chart`, `app.kubernetes.io/*`) have been parameterized in `_helpers.tpl` making the schema agnostic to namespace collision and allowing multi-tenancy.

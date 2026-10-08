# State Management

Terraform manages the state of the infrastructure in `terraform.tfstate`.

## Security

State files and `.tfvars` naturally contain sensitive credentials, endpoint references, or client certificates needed to access Kubernetes infrastructure.

This repository enforces strict clean-state via `.gitignore`:
- `*.tfstate` and backups are never committed.
- `.terraform/` module and provider caches remain entirely local.

If deploying in a real cloud context, a remote backend (e.g., S3 + DynamoDB locking or GitLab Managed Terraform State) would be strictly required in `main.tf` to handle state security and collaboration. For this local DB Platform portfolio goal, local non-tracked state provides the necessary evidence artifact.

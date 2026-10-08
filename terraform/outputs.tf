output "cluster_name" {
  description = "The name of the provisioned kind cluster"
  value       = kind_cluster.this.name
}

output "kubeconfig" {
  description = "The kubeconfig for the provisioned cluster"
  value       = kind_cluster.this.kubeconfig
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate for the cluster"
  value       = kind_cluster.this.client_certificate
  sensitive   = true
}
output "client_key" {
  description = "Client key for the cluster"
  value       = kind_cluster.this.client_key
  sensitive   = true
}
output "cluster_ca_certificate" {
  description = "CA certificate for the cluster"
  value       = kind_cluster.this.cluster_ca_certificate
  sensitive   = true
}
output "endpoint" {
  description = "The endpoint of the Kubernetes API"
  value       = kind_cluster.this.endpoint
}

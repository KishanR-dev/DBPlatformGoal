variable "cluster_name" {
  type        = string
  description = "The name of the kind cluster to create"
  default     = "db-platform-tf"
}

variable "kubernetes_version" {
  type        = string
  description = "The version of Kubernetes to use for the nodes"
  default     = "v1.33.1"
}

variable "worker_node_count" {
  type        = number
  description = "Number of worker nodes in the cluster"
  default     = 2
}

variable "project_id" {
  type = string
}

variable "name" {
  description = "Cluster name."
  type        = string
}

variable "location" {
  description = "Zone (zonal cluster) or region (regional cluster)."
  type        = string
}

variable "network_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "pods_range_name" {
  description = "Name of the subnet secondary range used for pods."
  type        = string
}

variable "services_range_name" {
  description = "Name of the subnet secondary range used for services."
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "/28 range for the control plane's internal endpoint. Must not overlap any range in the VPC."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "Map of display name => CIDR allowed to reach the control plane endpoint. Empty = no restriction."
  type        = map(string)
  default     = {}
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "deletion_protection" {
  description = "When true, terraform destroy refuses to delete the cluster."
  type        = bool
  default     = false
}

variable "node_pool_name" {
  type    = string
  default = "primary"
}

variable "node_count" {
  description = "Nodes in the pool (total for a zonal cluster, per zone for a regional one)."
  type        = number
  default     = 3
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "service_account_email" {
  description = "Service account the nodes run as."
  type        = string
}

variable "network_tags" {
  type    = list(string)
  default = []
}

variable "enable_managed_prometheus" {
  description = "Google Managed Prometheus (GKE enables it by default on new clusters). Off: use a self-hosted Prometheus."
  type        = bool
  default     = false
}

variable "autoscaling_enabled" {
  description = "Let GKE's cluster autoscaler resize this pool between min_node_count and max_node_count (per zone for regional clusters)."
  type        = bool
  default     = false
}

variable "min_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 3
}

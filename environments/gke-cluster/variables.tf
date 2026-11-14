variable "project_id" {
  type    = string
  default = "cka-comingsoon"
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "zone" {
  description = "Zone of the (zonal) cluster and its nodes."
  type        = string
  default     = "us-east1-b"
}

variable "cluster_name" {
  type    = string
  default = "gke-lab"
}

variable "node_count" {
  description = "Nodes in the small system pool (runs Karpenter + core add-ons). Everything else is provisioned by Karpenter."
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "System pool machine type: e2-medium = 2 vCPU (shared-core) / 4 GB."
  type        = string
  default     = "e2-medium"
}

variable "master_cidr" {
  description = "/28 for the GKE control plane's private endpoint. Also the source of control-plane -> webhook firewall rules."
  type        = string
  default     = "172.16.0.0/28"
}

variable "karpenter_namespace" {
  type    = string
  default = "karpenter-system"
}

variable "karpenter_service_account" {
  description = "Kubernetes service account name used by the Karpenter chart (release name 'karpenter')."
  type        = string
  default     = "karpenter"
}

variable "disk_size_gb" {
  description = "Node boot disk size."
  type        = number
  default     = 50
}

variable "subnet_cidr" {
  description = "Node subnet. Kept distinct from the kubeadm cluster's 10.10.0.0/24."
  type        = string
  default     = "10.20.0.0/24"
}

variable "pod_cidr" {
  description = "Secondary range for pods."
  type        = string
  default     = "10.24.0.0/16"
}

variable "service_cidr" {
  description = "Secondary range for services."
  type        = string
  default     = "10.28.0.0/20"
}

variable "master_authorized_networks" {
  description = "Map of name => CIDR allowed to reach the Kubernetes API, e.g. { home = \"203.0.113.7/32\" }. Empty = reachable from anywhere (still requires Google auth)."
  type        = map(string)
  default     = {}
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "autoscaling_enabled" {
  description = "GKE node-pool autoscaling (like EKS min/max) for the system pool. Off by default: Karpenter scales the workload nodes."
  type        = bool
  default     = false
}

variable "min_node_count" {
  type    = number
  default = 2
}

variable "max_node_count" {
  type    = number
  default = 5
}

variable "project_id" { type = string }
variable "zone" { type = string }
variable "region" { type = string }

variable "control_plane" {
  type    = string
  default = "controlplane"
}

variable "bootstrap_id" {
  description = "terraform_data id of the kubeadm bootstrap; changing it re-runs the lab install."
  type        = string
}

variable "registry_repository" {
  description = "Artifact Registry Docker repository name (must already exist)."
  type        = string
  default     = "kafka-demo"
}

variable "build_app_image" {
  description = "Build and push the demo app image from this machine (needs docker + gcloud)."
  type        = bool
  default     = true
}

variable "strimzi_version" {
  type    = string
  default = "1.1.0"
}

variable "keda_version" {
  description = "KEDA 2.20 is tested against Kubernetes v1.33-v1.35."
  type        = string
  default     = "2.20.2"
}

variable "kube_prometheus_stack_version" {
  type    = string
  default = "93.1.0"
}

variable "metrics_server_version" {
  type    = string
  default = "v0.9.1"
}

# GCE persistent disks (pd-balanced) cannot be smaller than 10Gi; Prometheus is
# still capped at ~3GB by retentionSize.
variable "kafka_volume_size" {
  type    = string
  default = "10Gi"
}

variable "prometheus_volume_size" {
  type    = string
  default = "10Gi"
}

variable "grafana_volume_size" {
  type    = string
  default = "10Gi"
}

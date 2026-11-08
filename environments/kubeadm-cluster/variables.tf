variable "project_id" {
  type    = string
  default = "cka-comingsoon"
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "zone" {
  type    = string
  default = "us-east1-b"
}

variable "cluster_name" {
  type    = string
  default = "kubeadm"
}

variable "machine_type" {
  description = "Worker machine type: 2 vCPU / 8 GB, non-shared core."
  type        = string
  default     = "e2-standard-2"
}

variable "control_plane_machine_type" {
  description = "Control plane machine type: 2 vCPU / 4 GB (meets kubeadm's 2 CPU minimum)."
  type        = string
  default     = "e2-medium"
}

variable "state_bucket" {
  description = "GCS bucket holding the Terraform state; node SA gets object read/write on it."
  type        = string
  default     = "gcp-s3-bknd-bucket-7568"
}

variable "disk_size_gb" {
  description = "Boot disk size. Persistent data lives on external PD volumes via the CSI driver."
  type        = number
  default     = 20
}

variable "image" {
  description = "kubeadm-install.sh supports Ubuntu only."
  type        = string
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

variable "pod_cidr" {
  description = "Pod network CIDR; also used as the Calico IPPool. Must not overlap the subnet or service CIDR."
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}

variable "k8s_minor" {
  type    = string
  default = "v1.33"
}

variable "calico_version" {
  type    = string
  default = "v3.33.0"
}

variable "install_script_path" {
  description = "Path to kubeadm-install.sh (defaults to the repo's shell-scripts folder)."
  type        = string
  default     = ""
}

variable "worker3_zone" {
  description = "Zone for worker3 (must be in var.region and differ from var.zone)."
  type        = string
  default     = "us-east1-c"
}

variable "worker4_zone" {
  description = "Zone for worker4 (must be in var.region and differ from var.zone)."
  type        = string
  default     = "us-east1-d"
}

variable "registry_repository" {
  description = "Artifact Registry Docker repo for the demo app image."
  type        = string
  default     = "kafka-demo"
}

variable "build_app_image" {
  description = "Build/push the demo app image from this machine (needs docker + gcloud). Set false if already pushed."
  type        = bool
  default     = true
}

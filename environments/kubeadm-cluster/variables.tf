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
  description = "2 vCPU / 4 GB. e2-medium is the cheapest type that comfortably meets kubeadm's 2 CPU minimum."
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  type    = number
  default = 30
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

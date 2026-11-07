variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "control_plane" {
  type = string
}

variable "workers" {
  type = list(string)
}

variable "node_ips" {
  description = "Map of node name => internal IP."
  type        = map(string)
}

variable "instance_ids" {
  description = "Instance IDs; a change re-runs the bootstrap."
  type        = list(string)
}

variable "install_script_path" {
  description = "Path to kubeadm-install.sh."
  type        = string
}

variable "k8s_minor" {
  type    = string
  default = "v1.33"
}

variable "pod_cidr" {
  type = string
}

variable "service_cidr" {
  type = string
}

variable "calico_version" {
  type = string
}

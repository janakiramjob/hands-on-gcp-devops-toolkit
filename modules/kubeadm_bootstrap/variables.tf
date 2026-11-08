variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "node_zones" {
  description = "Map of node name => zone. Nodes missing here use var.zone."
  type        = map(string)
  default     = {}
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

variable "helm_version" {
  description = "Helm 3 version installed on the control plane."
  type        = string
  default     = "v3.22.1"
}

variable "pd_csi_version" {
  description = "gcp-compute-persistent-disk-csi-driver git tag (deployed with the noauth overlay, i.e. node service account credentials)."
  type        = string
  default     = "v1.28.1"
}

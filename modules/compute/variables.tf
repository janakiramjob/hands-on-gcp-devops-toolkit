variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "nodes" {
  description = "Map of node name => { role, internal_ip, zone (optional) }."
  type = map(object({
    role        = string
    internal_ip = string
    zone        = optional(string) # defaults to var.zone
  }))
}

variable "machine_type" {
  type = string
}

variable "image" {
  type = string
}

variable "disk_size_gb" {
  type = number
}

variable "disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "network_tags" {
  type = list(string)
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "service_account_email" {
  type = string
}

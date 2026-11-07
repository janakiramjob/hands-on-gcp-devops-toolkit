variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "network_id" {
  description = "ID of the VPC this subnet belongs to."
  type        = string
}

variable "ip_cidr_range" {
  type = string
}

variable "secondary_ranges" {
  description = "Optional map of secondary range name => CIDR."
  type        = map(string)
  default     = {}
}

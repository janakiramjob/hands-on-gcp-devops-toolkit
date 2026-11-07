variable "name_prefix" {
  description = "Prefix for every firewall rule name."
  type        = string
}

variable "network_name" {
  description = "Name (or self_link) of the VPC the rules attach to."
  type        = string
}

variable "rules" {
  description = "Map of rule key => ingress rule definition."
  type = map(object({
    description   = string
    priority      = optional(number, 1000)
    source_ranges = list(string)
    target_tags   = list(string)
    allow = list(object({
      protocol = string
      ports    = optional(list(string))
    }))
  }))
}

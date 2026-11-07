variable "project_id" {
  type = string
}

variable "account_id" {
  type = string
}

variable "display_name" {
  type    = string
  default = ""
}

variable "roles" {
  description = "Project-level roles granted to the service account."
  type        = list(string)
  default     = []
}

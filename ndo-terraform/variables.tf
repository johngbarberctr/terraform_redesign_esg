variable "ndo_username" {
  description = "Username for NDO authentication"
  type        = string
}

variable "ndo_password" {
  description = "Password for NDO authentication"
  type        = string
  sensitive   = true
}

variable "ndo_url" {
  description = "URL of the NDO instance"
  type        = string
}

variable "vmm_domain_name" {
  description = "VMware VMM domain name in ACI/NDO for VMware integration"
  type        = string
}
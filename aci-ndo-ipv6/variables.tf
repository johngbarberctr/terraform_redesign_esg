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


variable "vrf_template_name" {
  description = "Template name for VRF resources (VRF for lab AFRICOM schema, UpgradeTemplate1 for production)"
  type        = string
  default     = "VRF"
}

variable "mso_domain" {
  description = "MSO provider domain (local for lab, null for production)"
  type        = string
  default     = null
}

variable "mso_platform" {
  description = "MSO provider platform (nd for lab, null for production)"
  type        = string
  default     = null
}
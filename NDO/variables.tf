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
variable "apic_url" {
  description = "APIC URL (e.g. https://apic.example.local)"
  type        = string
}

variable "apic_username" {
  description = "APIC username"
  type        = string
}

variable "apic_password" {
  description = "APIC password"
  type        = string
  sensitive   = true
}

variable "apic_insecure" {
  description = "Allow insecure APIC TLS"
  type        = bool
  default     = true
}

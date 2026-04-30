# ---------------------------------------------------------------------------
# NDO connection settings.
#
# Sensitive values (ndo_password) come from TF_VAR_ndo_password (env) /
# GitLab CI masked variable / Vault. Never commit credentials.
# ---------------------------------------------------------------------------
variable "ndo_url" {
  description = "Nexus Dashboard Orchestrator URL (e.g. https://ndo.example.com)"
  type        = string
}

variable "ndo_username" {
  description = "NDO username with admin/site-admin rights"
  type        = string
}

variable "ndo_password" {
  description = "NDO password. Supply via TF_VAR_ndo_password env var or GitLab CI masked variable."
  type        = string
  sensitive   = true
}

variable "ndo_insecure" {
  description = "Allow insecure NDO TLS (lab uses self-signed certs)"
  type        = bool
  default     = true
}

variable "ndo_platform" {
  description = <<-EOT
    NDO platform flavour:
      'nd'   -- Nexus Dashboard hosted (NDO 4.x+)
      'mso'  -- standalone MSO (legacy)
  EOT
  type        = string
  default     = "nd"
}

variable "ndo_domain" {
  description = "NDO/MSO authentication domain (Local for local users, e.g. 'local')."
  type        = string
  default     = "local"
}

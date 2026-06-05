# ---------------------------------------------------------------------------
# Kelley provider config (consumed by the DEFAULT, unaliased aci provider).
# ---------------------------------------------------------------------------
variable "kelley_apic_url" {
  description = "Kelley APIC URL (e.g. https://198.18.134.252 in lab)"
  type        = string
}

variable "kelley_apic_username" {
  description = "Kelley APIC username"
  type        = string
}

variable "kelley_apic_password" {
  description = "Kelley APIC password. Supply via TF_VAR_kelley_apic_password (env) / GitLab CI masked variable / Vault."
  type        = string
  sensitive   = true
}

variable "kelley_apic_insecure" {
  description = "Allow insecure APIC TLS for Kelley (lab APICs use self-signed certs)"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Del-Din provider config (consumed by the aliased aci.deldin provider).
# ---------------------------------------------------------------------------
variable "deldin_apic_url" {
  description = "Del-Din APIC URL (e.g. https://198.18.134.253 in lab)"
  type        = string
}

variable "deldin_apic_username" {
  description = "Del-Din APIC username"
  type        = string
}

variable "deldin_apic_password" {
  description = "Del-Din APIC password. Supply via TF_VAR_deldin_apic_password (env) / GitLab CI masked variable / Vault."
  type        = string
  sensitive   = true
}

variable "deldin_apic_insecure" {
  description = "Allow insecure APIC TLS for Del-Din"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# vCenter NOTE
# ---------------------------------------------------------------------------
# vCenter credentials are NOT Terraform variables -- they are consumed by
# scripts/render-vmm-yaml.sh via TF_VAR_vcenter_* environment variables that
# the script substitutes into templates/vmm-domain.nac.yaml.tftpl, producing
# ../data/nac-aci-<fabric>-rendered/vmm-domain.nac.yaml. Terraform then reads
# that static YAML through the nac-aci module.
#
# Both fabrics currently target the same vCenter, so the env vars are reused
# verbatim across `render-vmm-yaml.sh kelley` and `render-vmm-yaml.sh deldin`.
# If the fabrics ever need separate vCenters, introduce
# TF_VAR_<fabric>_vcenter_* and update the render script accordingly.
#
# This separation is intentional: see the comment at the top of main.tf for
# why rendering via a `local_file` resource inside Terraform breaks the
# nac-aci module's plan-time `for_each`/`count` evaluation.

# ---------------------------------------------------------------------------
# MCP Instance Policy keys (one per fabric).
# ---------------------------------------------------------------------------
variable "kelley_mcp_key" {
  description = <<-EOT
    Kelley MCP (MisCabling Protocol) Instance Policy password/key.

    APIC enforces complexity (>= 8 chars, mixed classes from lower/upper/
    digit/symbol). Weak values like "cisco" are rejected with HTTP 400 /
    Error 182.

    Sources, in order:
      1. Environment: export TF_VAR_kelley_mcp_key='<strong value>'
      2. GitLab CI/CD masked + protected variable named KELLEY_MCP_KEY
      3. Vault when stood up
    Never commit this value to Git.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.kelley_mcp_key) >= 8
    error_message = "kelley_mcp_key must be at least 8 characters to satisfy APIC MCP password complexity requirements."
  }
}

variable "deldin_mcp_key" {
  description = <<-EOT
    Del-Din MCP (MisCabling Protocol) Instance Policy password/key. Same rules
    as kelley_mcp_key. Use a DIFFERENT value than kelley_mcp_key so a leak of
    one fabric's key does not compromise the other.

    Sources, in order:
      1. Environment: export TF_VAR_deldin_mcp_key='<strong value>'
      2. GitLab CI/CD masked + protected variable named DELDIN_MCP_KEY
      3. Vault when stood up
    Never commit this value to Git.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.deldin_mcp_key) >= 8
    error_message = "deldin_mcp_key must be at least 8 characters to satisfy APIC MCP password complexity requirements."
  }
}

variable "manage_tenants" {
  description = "Allow this root to create/own the tenant object. true for lab (tenant may not yet exist); false for production (tenant pre-exists, managed out of band)."
  type        = bool
  default     = false
}

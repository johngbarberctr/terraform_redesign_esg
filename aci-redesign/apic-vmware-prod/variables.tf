# ---------------------------------------------------------------------------
# AEDCG provider config (consumed by the DEFAULT, unaliased aci provider).
# Variable names mirror the lab root so main.tf can be identical; only the
# VALUES differ at runtime (lab vs prod).
# ---------------------------------------------------------------------------
variable "aedcg_apic_url" {
  description = "AEDCG production APIC URL"
  type        = string
}

variable "aedcg_apic_username" {
  description = "AEDCG production APIC username"
  type        = string
}

variable "aedcg_apic_password" {
  description = "AEDCG production APIC password. Supply via TF_VAR_aedcg_apic_password (env) / GitLab CI masked variable AEDCG_APIC_PASSWORD_PROD / Vault."
  type        = string
  sensitive   = true
}

variable "aedcg_apic_insecure" {
  description = "Allow insecure APIC TLS for AEDCG production. Default true to mirror lab behaviour; set false (and supply a valid CA chain to the runner) for cert-pinned production."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# AEDCK provider config (consumed by the aliased aci.aedck provider).
# ---------------------------------------------------------------------------
variable "aedck_apic_url" {
  description = "AEDCK production APIC URL"
  type        = string
}

variable "aedck_apic_username" {
  description = "AEDCK production APIC username"
  type        = string
}

variable "aedck_apic_password" {
  description = "AEDCK production APIC password. Supply via TF_VAR_aedck_apic_password (env) / GitLab CI masked variable AEDCK_APIC_PASSWORD_PROD / Vault."
  type        = string
  sensitive   = true
}

variable "aedck_apic_insecure" {
  description = "Allow insecure APIC TLS for AEDCK production. See aedcg_apic_insecure for the production hardening note."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# vCenter NOTE
# ---------------------------------------------------------------------------
# vCenter credentials are NOT Terraform variables -- they are consumed by
# scripts/render-vmm-yaml.sh via TF_VAR_vcenter_* environment variables that
# the script substitutes into templates/vmm-domain.nac.yaml.tftpl, producing
# ../data/nac-aci-<fabric>-prod-rendered/vmm-domain.nac.yaml. Terraform then
# reads that static YAML through the nac-aci module.
#
# Both fabrics share one vCenter today, so the env vars are reused verbatim.
# The same TF_VAR_vcenter_* values used in the lab CAN be reused here only
# if lab and prod target the same vCenter; otherwise export different ones.

# ---------------------------------------------------------------------------
# MCP Instance Policy keys (one per fabric).
# ---------------------------------------------------------------------------
variable "aedcg_mcp_key" {
  description = <<-EOT
    AEDCG production MCP (MisCabling Protocol) Instance Policy password/key.

    APIC enforces complexity (>= 8 chars, mixed classes from lower/upper/
    digit/symbol). Use a DIFFERENT value than the lab MCP key.

    Sources, in order:
      1. Environment: export TF_VAR_aedcg_mcp_key='<strong value>'
      2. GitLab CI/CD masked + protected variable named AEDCG_MCP_KEY_PROD
      3. Vault when stood up
    Never commit this value to Git.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.aedcg_mcp_key) >= 8
    error_message = "aedcg_mcp_key must be at least 8 characters to satisfy APIC MCP password complexity requirements."
  }
}

variable "aedck_mcp_key" {
  description = <<-EOT
    AEDCK production MCP Instance Policy password/key. Same rules as
    aedcg_mcp_key. Use a DIFFERENT value than aedcg_mcp_key so a leak of
    one fabric's key does not compromise the other; ALSO different from
    the lab keys.

    Sources, in order:
      1. Environment: export TF_VAR_aedck_mcp_key='<strong value>'
      2. GitLab CI/CD masked + protected variable named AEDCK_MCP_KEY_PROD
      3. Vault when stood up
    Never commit this value to Git.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.aedck_mcp_key) >= 8
    error_message = "aedck_mcp_key must be at least 8 characters to satisfy APIC MCP password complexity requirements."
  }
}

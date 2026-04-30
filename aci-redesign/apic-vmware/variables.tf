# ---------------------------------------------------------------------------
# AEDCG provider config (consumed by the DEFAULT, unaliased aci provider).
# ---------------------------------------------------------------------------
variable "aedcg_apic_url" {
  description = "AEDCG APIC URL (e.g. https://198.18.134.253 in lab)"
  type        = string
}

variable "aedcg_apic_username" {
  description = "AEDCG APIC username"
  type        = string
}

variable "aedcg_apic_password" {
  description = "AEDCG APIC password. Supply via TF_VAR_aedcg_apic_password (env) / GitLab CI masked variable / Vault."
  type        = string
  sensitive   = true
}

variable "aedcg_apic_insecure" {
  description = "Allow insecure APIC TLS for AEDCG (lab APICs use self-signed certs)"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# AEDCK provider config (consumed by the aliased aci.aedck provider).
# ---------------------------------------------------------------------------
variable "aedck_apic_url" {
  description = "AEDCK APIC URL (e.g. https://198.18.134.254 in lab)"
  type        = string
}

variable "aedck_apic_username" {
  description = "AEDCK APIC username"
  type        = string
}

variable "aedck_apic_password" {
  description = "AEDCK APIC password. Supply via TF_VAR_aedck_apic_password (env) / GitLab CI masked variable / Vault."
  type        = string
  sensitive   = true
}

variable "aedck_apic_insecure" {
  description = "Allow insecure APIC TLS for AEDCK"
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
# verbatim across `render-vmm-yaml.sh aedcg` and `render-vmm-yaml.sh aedck`.
# If the fabrics ever need separate vCenters, introduce
# TF_VAR_<fabric>_vcenter_* and update the render script accordingly.
#
# This separation is intentional: see the comment at the top of main.tf for
# why rendering via a `local_file` resource inside Terraform breaks the
# nac-aci module's plan-time `for_each`/`count` evaluation.

# ---------------------------------------------------------------------------
# MCP Instance Policy keys (one per fabric).
# ---------------------------------------------------------------------------
variable "aedcg_mcp_key" {
  description = <<-EOT
    AEDCG MCP (MisCabling Protocol) Instance Policy password/key.

    APIC enforces complexity (>= 8 chars, mixed classes from lower/upper/
    digit/symbol). Weak values like "cisco" are rejected with HTTP 400 /
    Error 182.

    Sources, in order:
      1. Environment: export TF_VAR_aedcg_mcp_key='<strong value>'
      2. GitLab CI/CD masked + protected variable named AEDCG_MCP_KEY
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
    AEDCK MCP (MisCabling Protocol) Instance Policy password/key. Same rules
    as aedcg_mcp_key. Use a DIFFERENT value than aedcg_mcp_key so a leak of
    one fabric's key does not compromise the other.

    Sources, in order:
      1. Environment: export TF_VAR_aedck_mcp_key='<strong value>'
      2. GitLab CI/CD masked + protected variable named AEDCK_MCP_KEY
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

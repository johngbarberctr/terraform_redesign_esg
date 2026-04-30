# Multi-fabric provider wiring. Two aci providers in one Terraform root:
#
#   provider "aci"          (default, unaliased) -> AEDCG (var.aedcg_apic_*)
#   provider "aci.aedck"    (aliased)             -> AEDCK (var.aedck_apic_*)
#
# Modules opt in to the AEDCK provider via `providers = { aci = aci.aedck }`.
# Modules with no `providers` line inherit the default (= AEDCG), which
# preserves existing AEDCG state without a provider migration.

provider "aci" {
  url      = var.aedcg_apic_url
  username = var.aedcg_apic_username
  password = var.aedcg_apic_password
  insecure = var.aedcg_apic_insecure
}

provider "aci" {
  alias    = "aedck"
  url      = var.aedck_apic_url
  username = var.aedck_apic_username
  password = var.aedck_apic_password
  insecure = var.aedck_apic_insecure
}

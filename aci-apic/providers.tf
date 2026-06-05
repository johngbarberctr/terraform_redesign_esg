# Multi-fabric provider wiring. Two aci providers in one Terraform root:
#
#   provider "aci"           (default, unaliased) -> Kelley (var.kelley_apic_*)
#   provider "aci.deldin"    (aliased)             -> Del-Din (var.deldin_apic_*)
#
# Modules opt in to the Del-Din provider via `providers = { aci = aci.deldin }`.
# Modules with no `providers` line inherit the default (= Kelley), which
# preserves existing Kelley state without a provider migration.

provider "aci" {
  url      = var.kelley_apic_url
  username = var.kelley_apic_username
  password = var.kelley_apic_password
  insecure = var.kelley_apic_insecure
}

provider "aci" {
  alias    = "deldin"
  url      = var.deldin_apic_url
  username = var.deldin_apic_username
  password = var.deldin_apic_password
  insecure = var.deldin_apic_insecure
}

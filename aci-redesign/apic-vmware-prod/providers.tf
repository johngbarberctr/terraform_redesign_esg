# Production multi-fabric provider wiring -- mirrors the lab apic-vmware/
# providers exactly. Two aci providers in one Terraform root:
#
#   provider "aci"          (default, unaliased) -> AEDCG (var.aedcg_apic_*)
#   provider "aci.aedck"    (aliased)            -> AEDCK (var.aedck_apic_*)
#
# Variable NAMES match the lab root so the same Terraform code (main.tf and
# the two `module "aci_<fabric>"` blocks) can be reused without changes;
# only the VALUES come from prod env vars / GitLab CI variables suffixed
# *_PROD (see .gitlab-ci.yml). The strict separation is at the CI layer:
# lab and prod jobs read from different masked variable sets, never share
# Terraform state, and run in different resource groups.

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

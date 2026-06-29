# pipeline triggered: 2026-06-24T18:58:02Z
terraform {
  # GitLab HTTP backend for CI. Local users override to local state via a
  # gitignored `local_override.tf` containing:
  #     terraform { backend "local" {} }
  backend "http" {}

  required_providers {
    mso = {
      source  = "CiscoDevNet/mso"
      version = "~> 1.6"
    }
  }
}

# ---------------------------------------------------------------------------
# NDO-managed tenant root for the V2 (consolidated) tenant redesign.
#
# This root manages tenant AFR-DEL.Services and its full template tree (VRFs, filters,
# contracts, BDs, EPGs, ESGs, ANPs) in Nexus Dashboard Orchestrator. NDO
# pushes the resulting objects down to Kelley and Del-Din APICs.
#
# Sister roots:
#   ../aci-apic/      -- per-fabric APIC-direct (access policies, fabric
#                           policies, MCP, AAEP, VPC, vmmDomP).
#   ../aci-ndo-ipv6/     -- hand-written mso_schema_template_* HCL for the
#                           IPv6 RCC schema. Untouched here. Migrating that to
#                           the same nac-ndo YAML idiom is a follow-up.
#
# YAML directory:
#   ../data/nac-ndo/   ndo top-level with sites + tenants + schemas. The
#                      AFRICOM-V2 schema declares a single template
#                      (Tenant_AFR-DEL.Services_V2) carrying VRFs, contracts, BDs, ANPs,
#                      and EPGs. All target sites Kelley and Del-Din.
#
# Naming convention:
#   Every tenant-scoped object in AFRICOM-V2 carries a -V2 suffix (BDs, EPGs,
#   VRFs, contracts, ANPs). The legacy AFRICOM schema (managed by
#   ../../../sac-johbarbe-AFRICOM-terraform-nac-ndo) deploys to the same tenant AFR-DEL.Services; ACI
#   enforces unique object names per tenant, so distinct names are required
#   for parallel coexistence. The suffix is generational, not address-family
#   -- V2 BDs will eventually carry both IPv4 and IPv6 subnets. See
#   ../DESIGN.md "Naming convention" for the full rationale.
#
# Module flags:
#   manage_sites            = false  -- Kelley/Del-Din already onboarded into
#                                       NDO; we only reference them.
#   manage_tenants          = false  -- tenant AFR-DEL.Services already exists in NDO
#                                       (created out of band). Templates in
#                                       schema-africom-v2.nac.yaml reference
#                                       it by name; that does not require us
#                                       to own the mso_tenant resource. If we
#                                       ever want this root to own the tenant,
#                                       flip back to true and run:
#                                         terraform import \
#                                           'module.ndo.module.tenants[0].mso_tenant.tenant["AFR-DEL.Services"]' AFR-DEL.Services
#   manage_schemas          = true   -- schemas + templates + all child
#                                       resources (vrfs/bds/contracts/epgs).
#   deploy_templates        = false  -- create the schema/templates/objects
#                                       in NDO only. The push to Kelley and
#                                       Del-Din is done manually from the NDO
#                                       UI (Application Management -> Schemas
#                                       -> AFRICOM-V2 -> Deploy to sites) so
#                                       the operator controls timing per
#                                       template. Flip to true once the
#                                       schema content has been validated
#                                       and you want Terraform to drive
#                                       deploy as part of `apply`.
#
# State migration: the APIC-direct tenant tree was orphaned out of the
# ../aci-apic/ state via `terraform state rm` (see README cutover section).
# The objects still exist on the APICs; this root layers an NDO-managed
# schema on top. NDO will absorb / collide with same-named APIC-local objects
# on first deploy -- review the plan carefully and expect a maintenance
# window for the first push.
# ---------------------------------------------------------------------------

module "ndo" {
  source  = "netascode/nac-ndo/mso"
  version = "~> 1.2.0"

  yaml_directories = ["./data/nac-ndo"]

  manage_system            = false
  manage_sites             = false
  manage_site_connectivity = false
  manage_tenants           = false
  manage_schemas           = true
  deploy_templates         = false
}

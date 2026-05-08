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
# NDO-managed tenant root for the IPv4 redesign.
#
# This root manages tenant EUR and its full template tree (VRFs, filters,
# contracts, BDs, EPGs, ESGs, ANPs) in Nexus Dashboard Orchestrator. NDO
# pushes the resulting objects down to AEDCG and AEDCK APICs.
#
# Sister roots:
#   ../apic-vmware/      -- per-fabric APIC-direct (access policies, fabric
#                           policies, MCP, AAEP, VPC, vmmDomP).
#   ../../ndo-terraform/ -- legacy hand-written mso_schema_template_* HCL for
#                           the IPv6 RCC schema. Untouched here. Migrating
#                           that to the same nac-ndo YAML idiom is a follow-up.
#
# YAML directory:
#   ../data/nac-ndo/   ndo top-level with sites + tenants + schemas. The
#                      AEDCE-IPv4 schema declares three templates:
#                        Tenant_Policy   -- VRFs, filters, contracts
#                        Stretched_BDs   -- 39 BDs (l2_stretch=true)
#                        App_Profiles    -- ANPs, EPGs, ESGs, VMM bindings
#                      All three associate to sites AEDCG and AEDCK.
#
# Module flags:
#   manage_sites            = false  -- AEDCG/AEDCK already onboarded into
#                                       NDO; we only reference them.
#   manage_tenants          = false  -- tenant EUR already exists in NDO
#                                       (created out of band). Templates in
#                                       schema-aedce-ipv4.nac.yaml reference
#                                       it by name; that does not require us
#                                       to own the mso_tenant resource. If we
#                                       ever want this root to own the tenant,
#                                       flip back to true and run:
#                                         terraform import \
#                                           'module.ndo.module.tenants[0].mso_tenant.tenant["EUR"]' EUR
#   manage_schemas          = true   -- schemas + templates + all child
#                                       resources (vrfs/bds/contracts/epgs).
#   deploy_templates        = false  -- create the schema/templates/objects
#                                       in NDO only. The push to AEDCG and
#                                       AEDCK is done manually from the NDO
#                                       UI (Application Management -> Schemas
#                                       -> AEDCE-IPv4 -> Deploy to sites) so
#                                       the operator controls timing per
#                                       template. Flip to true once the
#                                       schema content has been validated
#                                       and you want Terraform to drive
#                                       deploy as part of `apply`.
#
# State migration: the APIC-direct tenant tree was orphaned out of the
# ../apic-vmware/ state via `terraform state rm` (see README cutover section).
# The objects still exist on the APICs; this root layers an NDO-managed
# schema on top. NDO will absorb / collide with same-named APIC-local objects
# on first deploy -- review the plan carefully and expect a maintenance
# window for the first push.
# ---------------------------------------------------------------------------

module "ndo" {
  source  = "netascode/nac-ndo/mso"
  version = "~> 1.2.0"

  yaml_directories = ["../data/nac-ndo"]

  manage_system            = false
  manage_sites             = false
  manage_site_connectivity = false
  manage_tenants           = false
  manage_schemas           = true
  deploy_templates         = false
}

terraform {
  required_providers {
    aci = {
      source  = "CiscoDevNet/aci"
      version = ">= 2.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Multi-fabric layout (single Terraform root, two providers):
#
#   Provider "aci"        (default, unaliased) -> AEDCG (var.aedcg_apic_*)
#   Provider "aci.aedck"  (aliased)            -> AEDCK (var.aedck_apic_*)
#
# YAML directories per module:
#   ../data/nac-aci-shared/           cross-fabric policy. Today this holds:
#                                       - modules.nac.yaml (disable wrapper's
#                                         MCP submodule, see below)
#                                       - tenant-eur-esgs.nac.yaml (the
#                                         AppProf-AppCentric-V2 ANP and the
#                                         two ESGs that overlay the
#                                         NDO-managed NetCentric/DMZ EPGs;
#                                         see that file's header for why
#                                         ESGs live APIC-direct instead of
#                                         in NDO).
#                                     Anything in here lands on every fabric.
#   ../data/nac-aci-aedcg/            AEDCG-specific access/fabric policy
#                                     (leaf 152-153 selectors, AAEP, VPC).
#   ../data/nac-aci-aedcg-rendered/   gitignored. vmm-domain.nac.yaml produced
#                                     by `scripts/render-vmm-yaml.sh aedcg`
#                                     before `terraform plan`.
#   ../data/nac-aci-aedck/            AEDCK-specific access/fabric policy
#                                     (leaf 119/191 selectors, AAEP, VPC).
#   ../data/nac-aci-aedck-rendered/   gitignored. produced by
#                                     `scripts/render-vmm-yaml.sh aedck`.
#
# The render step is intentionally OUT OF BAND. A `local_file` resource here
# would force the nac-aci module to depends_on an unapplied resource, which
# defers every internal `for_each`/`count` to apply time and breaks plan.
# The Makefile (`make plan` / `make apply`) and the GitLab CI plan/deploy
# jobs always run the render script for both fabrics first.
# ---------------------------------------------------------------------------

# State migration: the previous monolithic module names ("aci", "aci_mcp")
# become per-fabric ("aci_aedcg", "aci_mcp_aedcg"). Terraform applies these
# as in-place state moves; no destroy/recreate. The default provider stays
# the same FQN (registry.terraform.io/CiscoDevNet/aci, no alias) so the
# existing AEDCG resources do not see a provider change either.
moved {
  from = module.aci
  to   = module.aci_aedcg
}

# Chained migration for AEDCG: original state used the singular wrapper
# module.aci_mcp (pre-multi-fabric), then briefly the per-fabric wrapper
# module.aci_mcp_aedcg (introduced earlier in this session). Terraform follows
# moved chains, so listing the hops separately is fine; the only constraint is
# that each destination must appear in exactly one block. Hence the chain:
#   module.aci_mcp -> module.aci_mcp_aedcg -> aci_rest_managed.mcp_inst_pol_aedcg
moved {
  from = module.aci_mcp.aci_rest_managed.mcpInstPol
  to   = module.aci_mcp_aedcg.aci_rest_managed.mcpInstPol
}

moved {
  from = module.aci_mcp_aedcg.aci_rest_managed.mcpInstPol
  to   = aci_rest_managed.mcp_inst_pol_aedcg
}

# AEDCK never had a singular-wrapper predecessor (the alias was added at the
# same time as the per-fabric split), so a single hop is enough. Harmless if
# no matching state exists.
moved {
  from = module.aci_mcp_aedck.aci_rest_managed.mcpInstPol
  to   = aci_rest_managed.mcp_inst_pol_aedck
}

module "aci_aedcg" {
  source  = "netascode/nac-aci/aci"
  version = "0.7.0"

  yaml_directories = [
    "./data/nac-aci-shared",
    "./data/nac-aci-aedcg",
    "./data/nac-aci-aedcg-rendered",
  ]

  # Tenant-scoped split (see ../README.md for the cutover sequence):
  #   * NDO-managed (../ndo/, schema AEDCE-V2, deploy_templates=false):
  #     VRFs, BDs, contracts, filters, AppProf-NetCentric-V2 (36 internal
  #     EPGs), AppProf-DMZ-V2 (3 DMZ EPGs), EPG-to-VMM bindings.
  #   * APIC-direct here (../data/nac-aci-shared/tenant-eur-esgs.nac.yaml):
  #     AppProf-AppCentric-V2 ANP and two ESGs (ESG-All-Internal-V2,
  #     ESG-All-DMZ-V2) selecting all NetCentric/DMZ EPGs respectively.
  #     This wrapper module owns the tenant entry on first apply -- see
  #     "Tenant ownership" in tenant-eur-esgs.nac.yaml for the first-plan
  #     drift heads-up.
  manage_access_policies    = true
  manage_fabric_policies    = true
  manage_pod_policies       = false
  manage_node_policies      = false
  manage_interface_policies = true
  manage_tenants            = var.manage_tenants
}

# MCP Instance Policy is managed inline (not via the netascode/mcp/aci wrapper)
# because the wrapper's `lifecycle { ignore_changes = [content["key"]] }`
# interacts badly with `aci_rest_managed`'s map-typed `content` schema: the
# `key` field gets omitted from the CREATE payload, not just from drift
# detection, so APIC rejects with error 182 ("Password is required for MCP
# Instance Policy") on the first apply. Managing the resource inline lets us
# control the lifecycle (no ignore_changes) and guarantees `key` is in the
# payload on every plan/apply.
#
# The wrapper's internal aci_mcp sub-module is disabled in
# data/nac-aci-shared/modules.nac.yaml to avoid two Terraform resources
# targeting uni/infra/mcpInstP-default per fabric.
#
# Trade-off: the MCP key now lives in Terraform state (encrypted at rest if
# the backend supports it) and rotating it produces a tracked diff. The
# CI/Vault story for the key remains unchanged -- it still flows in via
# var.aedcg_mcp_key / var.aedck_mcp_key from TF_VAR_*_mcp_key env vars.
resource "aci_rest_managed" "mcp_inst_pol_aedcg" {
  dn         = "uni/infra/mcpInstP-default"
  class_name = "mcpInstPol"
  content = {
    adminSt        = "enabled"
    ctrl           = "pdu-per-vlan"
    initDelayTime  = "180"
    key            = var.aedcg_mcp_key
    loopDetectMult = "3"
    loopProtectAct = "port-disable"
    txFreq         = "2"
    txFreqMsec     = "0"
  }
}

module "aci_aedck" {
  source  = "netascode/nac-aci/aci"
  version = "0.7.0"

  providers = {
    aci = aci.aedck
  }

  yaml_directories = [
    "./data/nac-aci-shared",
    "./data/nac-aci-aedck",
    "./data/nac-aci-aedck-rendered",
  ]

  # See AEDCG module above for the tenant split. The same shared YAML
  # (tenant-eur-esgs.nac.yaml) is loaded here, so AEDCK gets identical
  # AppProf-AppCentric-V2 + ESGs.
  manage_access_policies    = true
  manage_fabric_policies    = true
  manage_pod_policies       = false
  manage_node_policies      = false
  manage_interface_policies = true
  manage_tenants            = var.manage_tenants
}

# AEDCK counterpart -- same shape as mcp_inst_pol_aedcg, routed through the
# aliased aci.aedck provider. See the comment block above the AEDCG resource
# for why we don't use the netascode/mcp/aci wrapper here.
resource "aci_rest_managed" "mcp_inst_pol_aedck" {
  provider   = aci.aedck
  dn         = "uni/infra/mcpInstP-default"
  class_name = "mcpInstPol"
  content = {
    adminSt        = "enabled"
    ctrl           = "pdu-per-vlan"
    initDelayTime  = "180"
    key            = var.aedck_mcp_key
    loopDetectMult = "3"
    loopProtectAct = "port-disable"
    txFreq         = "2"
    txFreqMsec     = "0"
  }
}

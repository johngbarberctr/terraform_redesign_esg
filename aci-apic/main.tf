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
#   Provider "aci"           (default, unaliased) -> Kelley (var.kelley_apic_*)
#   Provider "aci.deldin"    (aliased)             -> Del-Din (var.deldin_apic_*)
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
#   ../data/nac-aci-site1/            Kelley-specific access/fabric policy
#                                     (Leaf-101/102 selectors, AAEP, VPC).
#   ../data/nac-aci-site2/            Del-Din-specific access/fabric policy
#                                     (Leaf-101/102 selectors, AAEP, VPC).
#
# NOTE: nac-aci-kelley-rendered/ and nac-aci-deldin-rendered/ (gitignored,
# produced by scripts/render-vmm-yaml.sh) are NO LONGER loaded. VMM domain
# configuration is commented out — AFRICOM already has VMM configured in APIC.
# ---------------------------------------------------------------------------


module "aci_kelley" {
  source  = "netascode/nac-aci/aci"
  version = "0.7.0"

  yaml_directories = [
    "./data/nac-aci-shared",
    "./data/nac-aci-site1",
    # "./data/nac-aci-kelley-rendered",  # VMM already configured in APIC
  ]

  # Tenant-scoped split (see ../README.md for the cutover sequence):
  #   * NDO-managed (../ndo/, schema AFRICOM-V2, deploy_templates=false):
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
# var.kelley_mcp_key / var.deldin_mcp_key from TF_VAR_*_mcp_key env vars.
# MCP Instance Policy commented out — AFRICOM already has MCP configured in APIC.
# resource "aci_rest_managed" "mcp_inst_pol_kelley" {
#   dn         = "uni/infra/mcpInstP-default"
#   class_name = "mcpInstPol"
#   content = {
#     adminSt        = "enabled"
#     ctrl           = "pdu-per-vlan"
#     initDelayTime  = "180"
#     key            = var.kelley_mcp_key
#     loopDetectMult = "3"
#     loopProtectAct = "port-disable"
#     txFreq         = "2"
#     txFreqMsec     = "0"
#   }
# }

module "aci_deldin" {
  source  = "netascode/nac-aci/aci"
  version = "0.7.0"

  providers = {
    aci = aci.deldin
  }

  yaml_directories = [
    "./data/nac-aci-shared",
    "./data/nac-aci-site2",
    # "./data/nac-aci-deldin-rendered",  # VMM already configured in APIC
  ]

  # See Kelley module above for the tenant split. The same shared YAML
  # (tenant-eur-esgs.nac.yaml) is loaded here, so Del-Din gets identical
  # AppProf-AppCentric-V2 + ESGs.
  manage_access_policies    = true
  manage_fabric_policies    = true
  manage_pod_policies       = false
  manage_node_policies      = false
  manage_interface_policies = true
  manage_tenants            = var.manage_tenants
}

# Del-Din counterpart -- same shape as mcp_inst_pol_kelley, routed through the
# aliased aci.deldin provider. See the comment block above the Kelley resource
# for why we don't use the netascode/mcp/aci wrapper here.
# MCP Instance Policy commented out — AFRICOM already has MCP configured in APIC.
# resource "aci_rest_managed" "mcp_inst_pol_deldin" {
#   provider   = aci.deldin
#   dn         = "uni/infra/mcpInstP-default"
#   class_name = "mcpInstPol"
#   content = {
#     adminSt        = "enabled"
#     ctrl           = "pdu-per-vlan"
#     initDelayTime  = "180"
#     key            = var.deldin_mcp_key
#     loopDetectMult = "3"
#     loopProtectAct = "port-disable"
#     txFreq         = "2"
#     txFreqMsec     = "0"
#   }
# }

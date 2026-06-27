terraform {
  required_providers {
    aci = {
      source  = "CiscoDevNet/aci"
      version = ">= 2.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Multi-fabric layout for AFRICOM NIPR (single Terraform root, two providers):
#
#   Provider "aci"           (default, unaliased) -> Kelley (var.kelley_apic_*)
#   Provider "aci.deldin"    (aliased)             -> Del Din (var.deldin_apic_*)
#
# YAML directories per module:
#   ./data/nac-aci-shared/           Cross-fabric policy. Contains:
#                                      - modules.nac.yaml (disable wrapper's
#                                        MCP submodule, see below)
#                                      - tenant-afrdel-esgs.nac.yaml (stub for
#                                        AFR-DEL.Services ESG layer; ESGs are
#                                        TODO pending NDO schema export and
#                                        vzAny removal)
#                                    Anything in here lands on every fabric.
#   ./data/nac-aci-kelley/           Kelley-specific access/fabric policy
#                                    (NADE02LF101/102 selectors, AAEP, VPC).
#   ./data/nac-aci-kelley-rendered/  gitignored. vmm-domain.nac.yaml produced
#                                    by `scripts/render-vmm-yaml.sh kelley`
#                                    before `terraform plan`.
#   ./data/nac-aci-deldin/           Del Din-specific access/fabric policy
#                                    (NAIT03LF101/102/BL103/BL104 selectors).
#   ./data/nac-aci-deldin-rendered/  gitignored. produced by
#                                    `scripts/render-vmm-yaml.sh deldin`.
#
# The render step is intentionally OUT OF BAND. A `local_file` resource here
# would force the nac-aci module to depends_on an unapplied resource, which
# defers every internal `for_each`/`count` to apply time and breaks plan.
# The Makefile (`make plan` / `make apply`) and the GitLab CI plan/deploy
# jobs always run the render script for both fabrics first.
# ---------------------------------------------------------------------------


module "aci_kelley" {
  source  = "netascode/nac-aci/aci"
  version = "0.7.0"

  yaml_directories = [
    "./data/nac-aci-shared",
    "./data/nac-aci-kelley",
    "./data/nac-aci-kelley-rendered",
  ]

  # Tenant-scoped split:
  #   * NDO-managed (../africom-aci-ndo/, schema AFRICOM NIPR):
  #     VRFs, BDs, contracts, filters, EPGs, EPG-to-VMM bindings.
  #   * APIC-direct here (./data/nac-aci-shared/tenant-afrdel-esgs.nac.yaml):
  #     AFR-DEL.Services tenant entry + ESG layer (TODO -- populate after
  #     vzAny is removed and EPG catalog is confirmed from NDO schema export).
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
resource "aci_rest_managed" "mcp_inst_pol_kelley" {
  dn         = "uni/infra/mcpInstP-default"
  class_name = "mcpInstPol"
  content = {
    adminSt        = "enabled"
    ctrl           = "pdu-per-vlan"
    initDelayTime  = "180"
    key            = var.kelley_mcp_key
    loopDetectMult = "3"
    loopProtectAct = "port-disable"
    txFreq         = "2"
    txFreqMsec     = "0"
  }
}

module "aci_deldin" {
  source  = "netascode/nac-aci/aci"
  version = "0.7.0"

  providers = {
    aci = aci.deldin
  }

  yaml_directories = [
    "./data/nac-aci-shared",
    "./data/nac-aci-deldin",
    "./data/nac-aci-deldin-rendered",
  ]

  # See Kelley module above for the tenant split. The same shared YAML
  # (tenant-afrdel-esgs.nac.yaml) is loaded here, so Del Din gets identical
  # AFR-DEL.Services tenant entry + ESG stubs.
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
resource "aci_rest_managed" "mcp_inst_pol_deldin" {
  provider   = aci.deldin
  dn         = "uni/infra/mcpInstP-default"
  class_name = "mcpInstPol"
  content = {
    adminSt        = "enabled"
    ctrl           = "pdu-per-vlan"
    initDelayTime  = "180"
    key            = var.deldin_mcp_key
    loopDetectMult = "3"
    loopProtectAct = "port-disable"
    txFreq         = "2"
    txFreqMsec     = "0"
  }
}

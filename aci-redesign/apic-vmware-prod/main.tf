terraform {
  required_providers {
    aci = {
      source  = "CiscoDevNet/aci"
      version = ">= 2.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# PRODUCTION APIC-direct root for the IPv4 redesign (Design A: UCS-FI direct
# attach without vPC). Sister of the lab `../apic-vmware/`. Same Terraform
# code shape (two providers, two modules, inline MCP), different inputs:
#
#   YAML directories (per module):
#     ../data/nac-aci-shared/                 -- cross-fabric policy.
#     ../data/nac-aci-aedcg-prod/             -- AEDCG production access policies
#                                                (PC_FI_A/PC_FI_B, fi-static-vlan-pool,
#                                                 leaf 152-153 split: VMM ports 8-48,
#                                                 FI uplinks on eth1/6 & eth1/7).
#     ../data/nac-aci-aedcg-prod-rendered/    gitignored. vmm-domain.nac.yaml
#                                                produced by `scripts/render-vmm-yaml.sh
#                                                aedcg` before `terraform plan`.
#     ../data/nac-aci-aedck-prod/             -- AEDCK production access policies
#                                                (leaves 119/191 split).
#     ../data/nac-aci-aedck-prod-rendered/    gitignored.
#
# Tenants are NDO-managed (../ndo/ + data/nac-ndo/schema-aedce-ipv4.nac.yaml);
# this root only owns access/fabric/interface policies and the per-fabric VMM
# domain object on each APIC, plus the inline MCP InstP resource.
#
# State separation: this root has its own GitLab Terraform state path
# (TF_HTTP_ADDRESS_ACI_PROD in .gitlab-ci.yml -> /terraform/state/aci-redesign-prod)
# distinct from the lab root's `aci-redesign` path. Lab and prod state never
# touch each other.
#
# CI gating: validate-aci-prod / plan-aci-prod / deploy-aci-prod jobs in
# .gitlab-ci.yml read the *_PROD masked variables, fan them out to the same
# TF_VAR_* names as the lab root, and run inside resource_group: aci-prod.
# deploy-aci-prod is `when: manual` to enforce a change window.
# ---------------------------------------------------------------------------

module "aci_aedcg" {
  source  = "netascode/nac-aci/aci"
  version = "0.7.0"

  yaml_directories = [
    "../data/nac-aci-shared",
    "../data/nac-aci-aedcg-prod",
    "../data/nac-aci-aedcg-prod-rendered",
  ]

  # Tenant-scoped objects (VRFs, BDs, EPGs, contracts, filters, ANPs, ESGs,
  # EPG-to-VMM bindings) come from the sister NDO root in ../ndo/. APIC-direct
  # keeps only access/fabric policies and the VMM domain object itself.
  manage_access_policies    = true
  manage_fabric_policies    = true
  manage_pod_policies       = false
  manage_node_policies      = false
  manage_interface_policies = true
  manage_tenants            = false
}

# MCP Instance Policy is managed inline (not via the netascode/mcp/aci wrapper)
# for the same reason as the lab root -- the wrapper's
# `lifecycle { ignore_changes = [content["key"]] }` interacts badly with
# aci_rest_managed's map-typed `content` schema and APIC rejects with error 182
# on the first apply. The wrapper's internal aci_mcp sub-module is disabled in
# data/nac-aci-shared/modules.nac.yaml.
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
    "../data/nac-aci-shared",
    "../data/nac-aci-aedck-prod",
    "../data/nac-aci-aedck-prod-rendered",
  ]

  manage_access_policies    = true
  manage_fabric_policies    = true
  manage_pod_policies       = false
  manage_node_policies      = false
  manage_interface_policies = true
  manage_tenants            = false
}

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

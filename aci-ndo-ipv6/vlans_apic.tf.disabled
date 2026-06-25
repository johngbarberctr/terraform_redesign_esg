# ============================================================================
# APIC VLAN CONFIGURATION - IPv6 RCC PROJECT
# ============================================================================
# Creates individual VLAN entries under the existing Pool_VLAN_All_Combined
# on both Site G and Site K APICs.
#
# Uses the aci.apic_g and aci.apic_k providers defined in l3outs_apic.tf.
#
# VLAN-to-BD mapping derived from the IPv6 RCC reference table in bds_epgs.tf.
# ============================================================================

# ============================================================================
# VARIABLES
# ============================================================================

variable "vlan_pool_name" {
  description = "Name of the existing VLAN pool on both APICs"
  type        = string
  default     = "VLAN_All_Combined"
}

variable "vlan_pool_alloc" {
  description = "Allocation mode of the existing VLAN pool (static or dynamic)"
  type        = string
  default     = "static"
}

# ============================================================================
# IPv6 VLAN MAP
# ============================================================================
# Func | VLAN | BD Name           | IPv6 Gateway
# -----|------|-------------------|----------------------------
# 01   | 3001 | BD-NMS            | 2609:efff:b33b:100::1/64
# 15   | 3021 | BD-NAC            | 2609:efff:b33b:1500::1/64
# 1b   | 3050 | BD-LB             | 2609:efff:b33b:1b00::1/64
# bc   | 3051 | BD-RCC-SVR        | 2609:efff:b33b:bc00::1/64
# bd   | 3052 | BD-RCC-DNS        | 2609:efff:b33b:bd00::1/64
# be   | 3053 | BD-RCC-DCO        | 2609:efff:b33b:be00::1/64
# bf   | 3054 | BD-RCC-UNIX       | 2609:efff:b33b:bf00::1/64
# ca   | 3055 | BD-PKI-SRV        | 2609:efff:b33b:ca00::1/64
# cb   | 3056 | BD-LMR            | 2609:efff:b33b:cb00::1/64
# d6   | 3057 | BD-D64-PROXY      | 2609:efff:b33b:d600::1/64
# d7   | 3058 | BD-RWEB-PROXY     | 2609:efff:b33b:d700::1/64
# d8   | 3059 | BD-FWEB-PROXY     | 2609:efff:b33b:d800::1/64
# e3   | 3060 | BD-FMWR-SVR       | 2609:efff:b33b:e300::1/64
# e9   | 3061 | BD-E911-SVR       | 2609:efff:b33b:e900::1/64
# ef   | 3062 | BD-GEF-MGMT       | 2609:efff:b33b:ef00::1/64
# 40   | 3064 | BD-VVOIP-MGMT     | 2609:efff:b33b:4000::1/64
# 41   | 3065 | BD-VVOIP-PROXY    | 2609:efff:b33b:4100::1/64
# 53   | 3083 | BD-DNS-MGMT       | 2609:efff:b33b:5300::1/64
# 66   | 3102 | BD-VHOST-MGMT     | 2609:efff:b33b:6600::1/64
# 69   | 3105 | BD-CFG-MGMT       | 2609:efff:b33b:6900::1/64
# a3   | 3163 | BD-ADM-DCO        | 2609:efff:b33b:a300::1/64
# ad   | 3173 | BD-AD             | 2609:efff:b33b:ad00::1/64
# af   | 3175 | BD-ADFS           | 2609:efff:b33b:af00::1/64
# c0   | 3192 | BD-ACAS-SCANNERS  | 2609:efff:b33b:c000::1/64
# c3   | 3195 | BD-SYSMAN         | 2609:efff:b33b:c300::1/64
# c5   | 3197 | BD-OCSP           | 2609:efff:b33b:c500::1/64
# c6   | 3198 | BD-ACAS-MGMT      | 2609:efff:b33b:c600::1/64
# d0   | 3208 | BD-PRINT-SVR      | 2609:efff:b33b:d000::1/64
# d1   | 3209 | BD-FILE-SVR       | 2609:efff:b33b:d100::1/64
# d2   | 3210 | BD-DHCP-SVR       | 2609:efff:b33b:d200::1/64
# d5   | 3213 | BD-SMTP-SVR       | 2609:efff:b33b:d500::1/64
# d9   | 3217 | BD-SYSLOG         | 2609:efff:b33b:d900::1/64
# db   | 3219 | BD-DB-SVR         | 2609:efff:b33b:db00::1/64
# dd   | 3221 | BD-BACKUP-SVR     | 2609:efff:b33b:dd00::1/64
# e0   | 3224 | BD-APP-SVR        | 2609:efff:b33b:e000::1/64
# e4   | 3228 | BD-WEB-SVR        | 2609:efff:b33b:e400::1/64
# e6   | 3230 | BD-PATCH          | 2609:efff:b33b:e600::1/64
# ec   | 3236 | BD-MECM           | 2609:efff:b33b:ec00::1/64
# c1   | 3442 | BD-C2C-SCANNERS   | 2609:efff:b33b:c001::1/64
# --   | 3500 | L3Out-RCC-E SVI   | (L3Out external SVI encap - separate pool, manual)
# ============================================================================

locals {
  ipv6_vlans = {
    # Infrastructure Management
    "3001" = "BD-NMS"
    "3021" = "BD-NAC"
    "3102" = "BD-VHOST-MGMT"
    "3105" = "BD-CFG-MGMT"
    "3195" = "BD-SYSMAN"
    "3230" = "BD-PATCH"
    "3236" = "BD-MECM"

    # Network Services
    "3050" = "BD-LB"
    "3083" = "BD-DNS-MGMT"
    "3051" = "BD-RCC-SVR"
    "3210" = "BD-DHCP-SVR"
    "3213" = "BD-SMTP-SVR"

    # Voice and Communications
    "3064" = "BD-VVOIP-MGMT"
    "3065" = "BD-VVOIP-PROXY"
    "3052" = "BD-RCC-DNS"
    "3053" = "BD-RCC-DCO"

    # Security Services
    "3192" = "BD-ACAS-SCANNERS"
    "3442" = "BD-C2C-SCANNERS"
    "3197" = "BD-OCSP"
    "3054" = "BD-RCC-UNIX"
    "3198" = "BD-ACAS-MGMT"

    # Directory and Authentication
    "3173" = "BD-AD"
    "3175" = "BD-ADFS"

    # Proxy Services
    "3055" = "BD-PKI-SRV"
    "3056" = "BD-LMR"
    "3057" = "BD-D64-PROXY"
    "3058" = "BD-RWEB-PROXY"
    "3059" = "BD-FWEB-PROXY"

    # Application and Web Servers
    "3224" = "BD-APP-SVR"
    "3228" = "BD-WEB-SVR"
    "3060" = "BD-FMWR-SVR"

    # RCC Services
    "3163" = "BD-ADM-DCO"
    "3061" = "BD-E911-SVR"
    "3062" = "BD-GEF-MGMT"

    # Storage Services
    "3208" = "BD-PRINT-SVR"
    "3209" = "BD-FILE-SVR"
    "3221" = "BD-BACKUP-SVR"

    # Database and Logging
    "3219" = "BD-DB-SVR"
    "3217" = "BD-SYSLOG"
  }
}

# ============================================================================
# VLAN POOLS - Create pool on each APIC before adding encap blocks
# ============================================================================

resource "aci_vlan_pool" "ipv6_pool_g" {
  provider   = aci.apic_g
  name       = var.vlan_pool_name
  alloc_mode = var.vlan_pool_alloc
}

resource "aci_vlan_pool" "ipv6_pool_k" {
  provider   = aci.apic_k
  name       = var.vlan_pool_name
  alloc_mode = var.vlan_pool_alloc
}

# ============================================================================
# SITE G (Site1) - VLAN ENTRIES
# ============================================================================

resource "aci_rest_managed" "ipv6_vlan_g" {
  for_each   = local.ipv6_vlans
  provider   = aci.apic_g
  dn         = "uni/infra/vlanns-[${var.vlan_pool_name}]-${var.vlan_pool_alloc}/from-[vlan-${each.key}]-to-[vlan-${each.key}]"
  class_name = "fvnsEncapBlk"
  content = {
    from      = "vlan-${each.key}"
    to        = "vlan-${each.key}"
    allocMode = "inherit"
    role      = "external"
  }
  depends_on = [aci_vlan_pool.ipv6_pool_g]
}

# ============================================================================
# SITE K (Site2) - VLAN ENTRIES
# ============================================================================

resource "aci_rest_managed" "ipv6_vlan_k" {
  for_each   = local.ipv6_vlans
  provider   = aci.apic_k
  dn         = "uni/infra/vlanns-[${var.vlan_pool_name}]-${var.vlan_pool_alloc}/from-[vlan-${each.key}]-to-[vlan-${each.key}]"
  class_name = "fvnsEncapBlk"
  content = {
    from      = "vlan-${each.key}"
    to        = "vlan-${each.key}"
    allocMode = "inherit"
    role      = "external"
  }
  depends_on = [aci_vlan_pool.ipv6_pool_k]
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "ipv6_vlans_configured" {
  description = "List of IPv6 VLANs configured on both APICs"
  value       = sort(keys(local.ipv6_vlans))
}

output "ipv6_vlan_count" {
  description = "Total number of IPv6 VLANs configured per APIC"
  value       = length(local.ipv6_vlans)
}

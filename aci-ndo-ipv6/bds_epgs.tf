# ============================================================================
# COMPLETE TERRAFORM CONFIGURATION - FINAL CORRECTED VERSION
# ============================================================================
# IPv6 Address Format: 2609:efff:b33b:[function_code]00::1/64
# All VLANs verified from actual VM deployment data
# 
# CORRECTED: VVOIP function codes
#   - Function 40 (not 41) = VVOIP-MGMT → 2609:efff:b33b:4000::1/64, VLAN 3064
#   - Function 41 (not 42) = VVOIP-PROXY → 2609:efff:b33b:4100::1/64, VLAN 3065
# ============================================================================

# ============================================================================
# IPv6 AND VLAN REFERENCE MAP - FINAL
# ============================================================================
#
# Func | BD Name           | IPv6 Subnet              | Gateway IP                   | VLAN | Public | Verified
# -----|-------------------|--------------------------|------------------------------|------|--------|----------
# 01   | BD-NMS            | 2609:efff:b33b:100::/64  | 2609:efff:b33b:100::1/64     | 3001 | No     | ✅ (manual - provider bug)
# 15   | BD-NAC            | 2609:efff:b33b:1500::/64 | 2609:efff:b33b:1500::1/64    | 3021 | No     | ✅
# 1b   | BD-LB             | 2609:efff:b33b:1b00::/64 | 2609:efff:b33b:1b00::1/64    | 3050 | No     | ⚠️
# 40   | BD-VVOIP-MGMT     | 2609:efff:b33b:4000::/64 | 2609:efff:b33b:4000::1/64    | 3064 | No     | ✅
# 41   | BD-VVOIP-PROXY    | 2609:efff:b33b:4100::/64 | 2609:efff:b33b:4100::1/64    | 3065 | No     | ✅
# 53   | BD-DNS-MGMT       | 2609:efff:b33b:5300::/64 | 2609:efff:b33b:5300::1/64    | 3083 | No     | ✅
# 66   | BD-VHOST-MGMT     | 2609:efff:b33b:6600::/64 | 2609:efff:b33b:6600::1/64    | 3102 | No     | ✅
# 69   | BD-CFG-MGMT       | 2609:efff:b33b:6900::/64 | 2609:efff:b33b:6900::1/64    | 3105 | No     | ✅
# a3   | BD-ADM-DCO        | 2609:efff:b33b:a300::/64 | 2609:efff:b33b:a300::1/64    | 3163 | No     | ✅
# ad   | BD-AD             | 2609:efff:b33b:ad00::/64 | 2609:efff:b33b:ad00::1/64    | 3173 | No     | ✅
# af   | BD-ADFS           | 2609:efff:b33b:af00::/64 | 2609:efff:b33b:af00::1/64    | 3175 | No     | ✅
# bc   | BD-AFRICOM-SVR        | 2609:efff:b33b:bc00::/64 | 2609:efff:b33b:bc00::1/64    | 3051 | No     | ⚠️
# bd   | BD-AFRICOM-DNS        | 2609:efff:b33b:bd00::/64 | 2609:efff:b33b:bd00::1/64    | 3052 | No     | ⚠️
# be   | BD-AFRICOM-DCO        | 2609:efff:b33b:be00::/64 | 2609:efff:b33b:be00::1/64    | 3053 | No     | ⚠️
# bf   | BD-AFRICOM-UNIX       | 2609:efff:b33b:bf00::/64 | 2609:efff:b33b:bf00::1/64    | 3054 | No     | ⚠️
# c0   | BD-ACAS-SCANNERS  | 2609:efff:b33b:c000::/64 | 2609:efff:b33b:c000::1/64    | 3192 | No     | ✅
# c1   | BD-C2C-SCANNERS   | 2609:efff:b33b:c001::/64 | 2609:efff:b33b:c001::1/64    | 3442 | No     | ✅
# c3   | BD-SYSMAN         | 2609:efff:b33b:c300::/64 | 2609:efff:b33b:c300::1/64    | 3195 | No     | ✅
# c5   | BD-OCSP           | 2609:efff:b33b:c500::/64 | 2609:efff:b33b:c500::1/64    | 3197 | No     | ✅
# c6   | BD-ACAS-MGMT      | 2609:efff:b33b:c600::/64 | 2609:efff:b33b:c600::1/64    | 3198 | No     | ✅
# ca   | BD-PKI-SRV        | 2609:efff:b33b:ca00::/64 | 2609:efff:b33b:ca00::1/64    | 3055 | No     | ⚠️
# cb   | BD-LMR            | 2609:efff:b33b:cb00::/64 | 2609:efff:b33b:cb00::1/64    | 3056 | No     | ⚠️
# d0   | BD-PRINT-SVR      | 2609:efff:b33b:d000::/64 | 2609:efff:b33b:d000::1/64    | 3208 | No     | ✅
# d1   | BD-FILE-SVR       | 2609:efff:b33b:d100::/64 | 2609:efff:b33b:d100::1/64    | 3209 | No     | ✅
# d2   | BD-DHCP-SVR       | 2609:efff:b33b:d200::/64 | 2609:efff:b33b:d200::1/64    | 3210 | No     | ✅
# d5   | BD-SMTP-SVR       | 2609:efff:b33b:d500::/64 | 2609:efff:b33b:d500::1/64    | 3213 | No     | ✅
# d6   | BD-D64-PROXY      | 2609:efff:b33b:d600::/64 | 2609:efff:b33b:d600::1/64    | 3057 | No     | ⚠️
# d7   | BD-RWEB-PROXY     | 2609:efff:b33b:d700::/64 | 2609:efff:b33b:d700::1/64    | 3058 | Yes    | ⚠️
# d8   | BD-FWEB-PROXY     | 2609:efff:b33b:d800::/64 | 2609:efff:b33b:d800::1/64    | 3059 | Yes    | ⚠️
# d9   | BD-SYSLOG         | 2609:efff:b33b:d900::/64 | 2609:efff:b33b:d900::1/64    | 3217 | No     | ✅
# db   | BD-DB-SVR         | 2609:efff:b33b:db00::/64 | 2609:efff:b33b:db00::1/64    | 3219 | No     | ✅
# dd   | BD-BACKUP-SVR     | 2609:efff:b33b:dd00::/64 | 2609:efff:b33b:dd00::1/64    | 3221 | No     | ✅
# e0   | BD-APP-SVR        | 2609:efff:b33b:e000::/64 | 2609:efff:b33b:e000::1/64    | 3224 | No     | ✅
# e3   | BD-FMWR-SVR       | 2609:efff:b33b:e300::/64 | 2609:efff:b33b:e300::1/64    | 3060 | No     | ⚠️
# e4   | BD-WEB-SVR        | 2609:efff:b33b:e400::/64 | 2609:efff:b33b:e400::1/64    | 3228 | Yes    | ✅
# e6   | BD-PATCH          | 2609:efff:b33b:e600::/64 | 2609:efff:b33b:e600::1/64    | 3230 | No     | ✅
# e9   | BD-E911-SVR       | 2609:efff:b33b:e900::/64 | 2609:efff:b33b:e900::1/64    | 3061 | No     | ⚠️
# ec   | BD-MECM           | 2609:efff:b33b:ec00::/64 | 2609:efff:b33b:ec00::1/64    | 3236 | No     | ✅
# ef   | BD-GEF-MGMT       | 2609:efff:b33b:ef00::/64 | 2609:efff:b33b:ef00::1/64    | 3062 | No     | ⚠️
#
# ✅ = VLAN verified from VM deployment data
# ⚠️ = VLAN not in data, assigned from safe range (3050-3062, 3500+)
#
# ============================================================================

# Data sources
data "mso_schema" "existing" {
  name = "AFRICOM"
}

data "mso_site" "site1" {
  name = "Kelley"
}

data "mso_site" "site2" {
  name = "Del-Din"
}

data "mso_tenant" "eur" {
  name = "AFR-DEL.Services"
}

# ============================================================================
# VRF DEFINITION
# ============================================================================

resource "mso_schema_template_vrf" "vrf_rcc" {
  schema_id        = data.mso_schema.existing.id
  template         = var.vrf_template_name
  name             = "AFR-PROD-V6"
  display_name     = "AFR-PROD-V6"
  layer3_multicast = false
  vzany            = true

  # The VRF identity is its name, so renaming VRF-RCC -> AFR-PROD-V6 is a
  # replacement. Create the new VRF before destroying the old one so the ~35
  # service BDs can be re-pointed first; otherwise NDO rejects the delete with
  # "Err Missing Ref" because BDs still reference VRF-RCC.
  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# CONTRACT AND FILTER
# ============================================================================

resource "mso_schema_template_contract" "contract_vrf_rcc" {
  schema_id     = data.mso_schema.existing.id
  template_name = var.vrf_template_name
  contract_name = "Any_AFR-PROD-V6"
  display_name  = "Any_AFR-PROD-V6"
  scope         = "context"
  filter_type   = "bothWay"

  filter_relationship {
    filter_schema_id     = data.mso_schema.existing.id
    filter_template_name = var.vrf_template_name
    filter_name          = "Any"
    filter_type          = "bothWay"
  }
}

# ============================================================================
# VZANY CONTRACT ASSOCIATION
# ============================================================================
# Assign the contract to vzAny on the VRF for inter-EPG communication

resource "mso_schema_template_vrf_contract" "vrf_rcc_vzany_provider" {
  schema_id              = data.mso_schema.existing.id
  template_name          = var.vrf_template_name
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  relationship_type      = "provider"
  contract_name          = mso_schema_template_contract.contract_vrf_rcc.contract_name
  contract_schema_id     = data.mso_schema.existing.id
  contract_template_name = var.vrf_template_name
}

resource "mso_schema_template_vrf_contract" "vrf_rcc_vzany_consumer" {
  schema_id              = data.mso_schema.existing.id
  template_name          = var.vrf_template_name
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  relationship_type      = "consumer"
  contract_name          = mso_schema_template_contract.contract_vrf_rcc.contract_name
  contract_schema_id     = data.mso_schema.existing.id
  contract_template_name = var.vrf_template_name
}
# ============================================================================
# L2_STRETCHED TEMPLATE
# ============================================================================

resource "mso_schema_template_anp" "appprof_rcc_stretched" {
  schema_id    = data.mso_schema.existing.id
  template     = "Stretched_Services"
  name         = "AppProf-AFR-PROD-V6"
  display_name = "AppProf-AFR-PROD-V6"
}

# ============================================================================
# Function: 15 - NAC | IPv6: 2609:efff:b33b:1500::1/64 | VLAN: 3021 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_nac" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-NAC"
  display_name                    = "BD-NAC"
  description                     = "Network Access Control - Function: 15 - VLAN: 3021"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_nac_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_nac.name
  ip            = "2609:efff:b33b:1500::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_nac" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-NAC"
  display_name  = "EPG-NAC"
  bd_name       = mso_schema_template_bd.bd_nac.name
}

# ============================================================================
# Function: 69 - CFG-MGMT | IPv6: 2609:efff:b33b:6900::1/64 | VLAN: 3105 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_cfg_mgmt" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-CFG-MGMT"
  display_name                    = "BD-CFG-MGMT"
  description                     = "Configuration Management - Function: 69 - VLAN: 3105"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_cfg_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_cfg_mgmt.name
  ip            = "2609:efff:b33b:6900::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_cfg_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-CFG-MGMT"
  display_name  = "EPG-CFG-MGMT"
  bd_name       = mso_schema_template_bd.bd_cfg_mgmt.name
}

# ============================================================================
# Function: ec - MECM | IPv6: 2609:efff:b33b:ec00::1/64 | VLAN: 3236 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_mecm" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-MECM"
  display_name                    = "BD-MECM"
  description                     = "Microsoft Endpoint Configuration Manager - Function: ec - VLAN: 3236"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_mecm_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_mecm.name
  ip            = "2609:efff:b33b:ec00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_mecm" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-MECM"
  display_name  = "EPG-MECM"
  bd_name       = mso_schema_template_bd.bd_mecm.name
}

# ============================================================================
# Function: 1b - LB | IPv6: 2609:efff:b33b:1b00::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_lb" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-LB"
  display_name                    = "BD-LB"
  description                     = "Load Balancer - Function: 1b"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_lb_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_lb.name
  ip            = "2609:efff:b33b:1b00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_lb" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-LB"
  display_name  = "EPG-LB"
  bd_name       = mso_schema_template_bd.bd_lb.name
}

# ============================================================================
# Function: 53 - DNS-MGMT | IPv6: 2609:efff:b33b:5300::1/64 | VLAN: 3083 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_dns_mgmt" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-DNS-MGMT"
  display_name                    = "BD-DNS-MGMT"
  description                     = "DNS Management - Function: 53 - VLAN: 3083"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_dns_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_dns_mgmt.name
  ip            = "2609:efff:b33b:5300::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_dns_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-DNS-MGMT"
  display_name  = "EPG-DNS-MGMT"
  bd_name       = mso_schema_template_bd.bd_dns_mgmt.name
}

# ============================================================================
# Function: bd - AFRICOM-DNS | IPv6: 2609:efff:b33b:bd00::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_rcc_dns" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-AFRICOM-DNS"
  display_name                    = "BD-AFRICOM-DNS"
  description                     = "AFRICOM DNS Services - Function: bd"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_rcc_dns_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_rcc_dns.name
  ip            = "2609:efff:b33b:bd00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rcc_dns" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-AFRICOM-DNS"
  display_name  = "EPG-AFRICOM-DNS"
  bd_name       = mso_schema_template_bd.bd_rcc_dns.name
}

# ============================================================================
# Function: d2 - DHCP-SVR | IPv6: 2609:efff:b33b:d200::1/64 | VLAN: 3210 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_dhcp_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-DHCP-SVR"
  display_name                    = "BD-DHCP-SVR"
  description                     = "DHCP Server - Function: d2 - VLAN: 3210"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_dhcp_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_dhcp_svr.name
  ip            = "2609:efff:b33b:d200::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_dhcp_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-DHCP-SVR"
  display_name  = "EPG-DHCP-SVR"
  bd_name       = mso_schema_template_bd.bd_dhcp_svr.name
}

# ============================================================================
# Function: d5 - SMTP-SVR | IPv6: 2609:efff:b33b:d500::1/64 | VLAN: 3213 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_smtp_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-SMTP-SVR"
  display_name                    = "BD-SMTP-SVR"
  description                     = "SMTP Server - Function: d5 - VLAN: 3213"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_smtp_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_smtp_svr.name
  ip            = "2609:efff:b33b:d500::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_smtp_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-SMTP-SVR"
  display_name  = "EPG-SMTP-SVR"
  bd_name       = mso_schema_template_bd.bd_smtp_svr.name
}

# ============================================================================
# Function: 40 - VVOIP-MGMT | IPv6: 2609:efff:b33b:4000::1/64 | VLAN: 3064 ✅ CORRECTED
# ============================================================================

resource "mso_schema_template_bd" "bd_vvoip_mgmt" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-VVOIP-MGMT"
  display_name                    = "BD-VVOIP-MGMT"
  description                     = "Video/Voice Management - Function: 40 - VLAN: 3064"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_vvoip_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_vvoip_mgmt.name
  ip            = "2609:efff:b33b:4000::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_vvoip_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-VVOIP-MGMT"
  display_name  = "EPG-VVOIP-MGMT"
  bd_name       = mso_schema_template_bd.bd_vvoip_mgmt.name
}

# ============================================================================
# Function: 41 - VVOIP-PROXY | IPv6: 2609:efff:b33b:4100::1/64 | VLAN: 3065 ✅ CORRECTED
# ============================================================================

resource "mso_schema_template_bd" "bd_vvoip_proxy" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-VVOIP-PROXY"
  display_name                    = "BD-VVOIP-PROXY"
  description                     = "Video/Voice Proxy - Function: 41 - VLAN: 3065"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_vvoip_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_vvoip_proxy.name
  ip            = "2609:efff:b33b:4100::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_vvoip_proxy" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-VVOIP-PROXY"
  display_name  = "EPG-VVOIP-PROXY"
  bd_name       = mso_schema_template_bd.bd_vvoip_proxy.name
}

# ============================================================================
# Function: cb - LMR | IPv6: 2609:efff:b33b:cb00::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_lmr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-LMR"
  display_name                    = "BD-LMR"
  description                     = "Land Mobile Radio - Function: cb"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_lmr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_lmr.name
  ip            = "2609:efff:b33b:cb00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_lmr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-LMR"
  display_name  = "EPG-LMR"
  bd_name       = mso_schema_template_bd.bd_lmr.name
}

# ============================================================================
# Function: e9 - E911-SVR | IPv6: 2609:efff:b33b:e900::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_e911_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-E911-SVR"
  display_name                    = "BD-E911-SVR"
  description                     = "Emergency Services - Function: e9"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_e911_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_e911_svr.name
  ip            = "2609:efff:b33b:e900::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_e911_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-E911-SVR"
  display_name  = "EPG-E911-SVR"
  bd_name       = mso_schema_template_bd.bd_e911_svr.name
}

# ============================================================================
# Function: c0 - ACAS-SCANNERS | IPv6: 2609:efff:b33b:c000::1/64 | VLAN: 3192 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_acas_scanners" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-ACAS-SCANNERS"
  display_name                    = "BD-ACAS-SCANNERS"
  description                     = "Assured Compliance Assessment Solution - Function: c0 - VLAN: 3192"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_acas_scanners_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_acas_scanners.name
  ip            = "2609:efff:b33b:c000::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_acas_scanners" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-ACAS-SCANNERS"
  display_name  = "EPG-ACAS-SCANNERS"
  bd_name       = mso_schema_template_bd.bd_acas_scanners.name
}

# ============================================================================
# Function: c1 - C2C-SCANNERS | IPv6: 2609:efff:b33b:c001::1/64 | VLAN: 3442 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_c2c_scanners" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-C2C-SCANNERS"
  display_name                    = "BD-C2C-SCANNERS"
  description                     = "C2C Vulnerability Scanners - Function: c1 - VLAN: 3442"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_c2c_scanners_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_c2c_scanners.name
  ip            = "2609:efff:b33b:c001::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_c2c_scanners" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-C2C-SCANNERS"
  display_name  = "EPG-C2C-SCANNERS"
  bd_name       = mso_schema_template_bd.bd_c2c_scanners.name
}

# ============================================================================
# Function: c5 - OCSP | IPv6: 2609:efff:b33b:c500::1/64 | VLAN: 3197 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_ocsp" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-OCSP"
  display_name                    = "BD-OCSP"
  description                     = "Online Certificate Status Protocol - Function: c5 - VLAN: 3197"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_ocsp_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_ocsp.name
  ip            = "2609:efff:b33b:c500::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_ocsp" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-OCSP"
  display_name  = "EPG-OCSP"
  bd_name       = mso_schema_template_bd.bd_ocsp.name
}

# ============================================================================
# Function: ca - PKI-SRV | IPv6: 2609:efff:b33b:ca00::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_pki_srv" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-PKI-SRV"
  display_name                    = "BD-PKI-SRV"
  description                     = "Public Key Infrastructure - Function: ca"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_pki_srv_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_pki_srv.name
  ip            = "2609:efff:b33b:ca00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_pki_srv" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-PKI-SRV"
  display_name  = "EPG-PKI-SRV"
  bd_name       = mso_schema_template_bd.bd_pki_srv.name
}

# ============================================================================
# Function: ad - AD | IPv6: 2609:efff:b33b:ad00::1/64 | VLAN: 3173 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_ad" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-AD"
  display_name                    = "BD-AD"
  description                     = "Active Directory - Function: ad - VLAN: 3173"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_ad_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_ad.name
  ip            = "2609:efff:b33b:ad00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_ad" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-AD"
  display_name  = "EPG-AD"
  bd_name       = mso_schema_template_bd.bd_ad.name
}

# ============================================================================
# Function: af - ADFS | IPv6: 2609:efff:b33b:af00::1/64 | VLAN: 3175 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_adfs" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-ADFS"
  display_name                    = "BD-ADFS"
  description                     = "Active Directory Federation Services - Function: af - VLAN: 3175"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_adfs_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_adfs.name
  ip            = "2609:efff:b33b:af00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_adfs" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-ADFS"
  display_name  = "EPG-ADFS"
  bd_name       = mso_schema_template_bd.bd_adfs.name
}

# ============================================================================
# Function: d6 - D64-PROXY | IPv6: 2609:efff:b33b:d600::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_d64_proxy" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-D64-PROXY"
  display_name                    = "BD-D64-PROXY"
  description                     = "DNS64 Proxy - Function: d6"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_d64_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_d64_proxy.name
  ip            = "2609:efff:b33b:d600::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_d64_proxy" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-D64-PROXY"
  display_name  = "EPG-D64-PROXY"
  bd_name       = mso_schema_template_bd.bd_d64_proxy.name
}

# ============================================================================
# Function: d7 - RWEB-PROXY | IPv6: 2609:efff:b33b:d700::1/64 | VLAN: Safe range | PUBLIC
# ============================================================================

resource "mso_schema_template_bd" "bd_rweb_proxy" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-RWEB-PROXY"
  display_name                    = "BD-RWEB-PROXY"
  description                     = "Reverse Web Proxy - Function: d7 - PUBLIC SERVICE"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_rweb_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_rweb_proxy.name
  ip            = "2609:efff:b33b:d700::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rweb_proxy" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-RWEB-PROXY"
  display_name  = "EPG-RWEB-PROXY"
  bd_name       = mso_schema_template_bd.bd_rweb_proxy.name
}

# ============================================================================
# Function: d8 - FWEB-PROXY | IPv6: 2609:efff:b33b:d800::1/64 | VLAN: Safe range | PUBLIC
# ============================================================================

resource "mso_schema_template_bd" "bd_fweb_proxy" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-FWEB-PROXY"
  display_name                    = "BD-FWEB-PROXY"
  description                     = "Forward Web Proxy - Function: d8 - PUBLIC SERVICE"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_fweb_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_fweb_proxy.name
  ip            = "2609:efff:b33b:d800::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_fweb_proxy" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-FWEB-PROXY"
  display_name  = "EPG-FWEB-PROXY"
  bd_name       = mso_schema_template_bd.bd_fweb_proxy.name
}

# ============================================================================
# Function: e0 - APP-SVR | IPv6: 2609:efff:b33b:e000::1/64 | VLAN: 3224 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_app_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-APP-SVR"
  display_name                    = "BD-APP-SVR"
  description                     = "Application Server - Function: e0 - VLAN: 3224"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_app_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_app_svr.name
  ip            = "2609:efff:b33b:e000::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_app_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-APP-SVR"
  display_name  = "EPG-APP-SVR"
  bd_name       = mso_schema_template_bd.bd_app_svr.name
}

# ============================================================================
# Function: e4 - WEB-SVR | IPv6: 2609:efff:b33b:e400::1/64 | VLAN: 3228 ✅ | PUBLIC
# ============================================================================

resource "mso_schema_template_bd" "bd_web_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-WEB-SVR"
  display_name                    = "BD-WEB-SVR"
  description                     = "Web Server - Function: e4 - VLAN: 3228 - PUBLIC SERVICE"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_web_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_web_svr.name
  ip            = "2609:efff:b33b:e400::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_web_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-WEB-SVR"
  display_name  = "EPG-WEB-SVR"
  bd_name       = mso_schema_template_bd.bd_web_svr.name
}

# ============================================================================
# Function: e3 - FMWR-SVR | IPv6: 2609:efff:b33b:e300::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_fmwr_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-FMWR-SVR"
  display_name                    = "BD-FMWR-SVR"
  description                     = "Firmware Server - Function: e3"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_fmwr_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_fmwr_svr.name
  ip            = "2609:efff:b33b:e300::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_fmwr_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-FMWR-SVR"
  display_name  = "EPG-FMWR-SVR"
  bd_name       = mso_schema_template_bd.bd_fmwr_svr.name
}

# ============================================================================
# Function: bc - AFRICOM-SVR | IPv6: 2609:efff:b33b:bc00::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_rcc_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-AFRICOM-SVR"
  display_name                    = "BD-AFRICOM-SVR"
  description                     = "AFRICOM Server - Function: bc"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_rcc_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_rcc_svr.name
  ip            = "2609:efff:b33b:bc00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rcc_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-AFRICOM-SVR"
  display_name  = "EPG-AFRICOM-SVR"
  bd_name       = mso_schema_template_bd.bd_rcc_svr.name
}

# ============================================================================
# Function: be - AFRICOM-DCO | IPv6: 2609:efff:b33b:be00::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_rcc_dco" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-AFRICOM-DCO"
  display_name                    = "BD-AFRICOM-DCO"
  description                     = "AFRICOM DCO - Function: be"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_rcc_dco_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_rcc_dco.name
  ip            = "2609:efff:b33b:be00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rcc_dco" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-AFRICOM-DCO"
  display_name  = "EPG-AFRICOM-DCO"
  bd_name       = mso_schema_template_bd.bd_rcc_dco.name
}

# ============================================================================
# Function: bf - AFRICOM-UNIX | IPv6: 2609:efff:b33b:bf00::1/64 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_rcc_unix" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-AFRICOM-UNIX"
  display_name                    = "BD-AFRICOM-UNIX"
  description                     = "AFRICOM UNIX - Function: bf"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_rcc_unix_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_rcc_unix.name
  ip            = "2609:efff:b33b:bf00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rcc_unix" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-AFRICOM-UNIX"
  display_name  = "EPG-AFRICOM-UNIX"
  bd_name       = mso_schema_template_bd.bd_rcc_unix.name
}

# ============================================================================
# Function: d0 - PRINT-SVR | IPv6: 2609:efff:b33b:d000::1/64 | VLAN: 3208 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_print_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-PRINT-SVR"
  display_name                    = "BD-PRINT-SVR"
  description                     = "Print Server - Function: d0 - VLAN: 3208"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_print_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_print_svr.name
  ip            = "2609:efff:b33b:d000::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_print_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-PRINT-SVR"
  display_name  = "EPG-PRINT-SVR"
  bd_name       = mso_schema_template_bd.bd_print_svr.name
}

# ============================================================================
# Function: d1 - FILE-SVR | IPv6: 2609:efff:b33b:d100::1/64 | VLAN: 3209 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_file_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-FILE-SVR"
  display_name                    = "BD-FILE-SVR"
  description                     = "File Server - Function: d1 - VLAN: 3209"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_file_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_file_svr.name
  ip            = "2609:efff:b33b:d100::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_file_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-FILE-SVR"
  display_name  = "EPG-FILE-SVR"
  bd_name       = mso_schema_template_bd.bd_file_svr.name
}

# ============================================================================
# Function: 01 - NMS | IPv6: 2609:efff:b33b:0100::1/64 | VLAN: 3001 ✅
# ============================================================================


resource "mso_schema_template_bd" "bd_nms" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-NMS"
  display_name                    = "BD-NMS"
  description                     = "Network Management System - Function: 01 - VLAN: 3001"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

/* Provider bug: NDO normalizes the 0100 segment differently than what the provider
   expects on read-back, causing "root object was present, but now absent" errors.
   This subnet is managed manually in NDO until the CiscoDevNet/mso provider is fixed.
resource "mso_schema_template_bd_subnet" "bd_nms_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_nms.name
  ip            = "2609:efff:b33b:100::1/64"
  scope         = "public"
  shared        = false
}
*/



resource "mso_schema_template_anp_epg" "epg_nms" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-NMS"
  display_name  = "EPG-NMS"
  bd_name       = mso_schema_template_bd.bd_nms.name
}


# ============================================================================
# Function: 66 - VHOST-MGMT | IPv6: 2609:efff:b33b:6600::1/64 | VLAN: 3102 ✅
# ============================================================================


resource "mso_schema_template_bd" "bd_vhost_mgmt" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-VHOST-MGMT"
  display_name                    = "BD-VHOST-MGMT"
  description                     = "vHost Management - Function: 66 - VLAN: 3102"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_vhost_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_vhost_mgmt.name
  ip            = "2609:efff:b33b:6600::1/64"
  scope         = "public"
  shared        = false
}



resource "mso_schema_template_anp_epg" "epg_vhost_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-VHOST-MGMT"
  display_name  = "EPG-VHOST-MGMT"
  bd_name       = mso_schema_template_bd.bd_vhost_mgmt.name
}


# ============================================================================
# Function: a3 - ADM-DCO | IPv6: 2609:efff:b33b:a300::1/64 | VLAN: 3163 ✅
# ============================================================================


resource "mso_schema_template_bd" "bd_adm_dco" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-ADM-DCO"
  display_name                    = "BD-ADM-DCO"
  description                     = "Admin DCO - Function: a3 - VLAN: 3163"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_adm_dco_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_adm_dco.name
  ip            = "2609:efff:b33b:a300::1/64"
  scope         = "public"
  shared        = false
}



resource "mso_schema_template_anp_epg" "epg_adm_dco" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-ADM-DCO"
  display_name  = "EPG-ADM-DCO"
  bd_name       = mso_schema_template_bd.bd_adm_dco.name
}


# ============================================================================
# Function: c3 - SYSMAN | IPv6: 2609:efff:b33b:c300::1/64 | VLAN: 3195 ✅
# ============================================================================


resource "mso_schema_template_bd" "bd_sysman" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-SYSMAN"
  display_name                    = "BD-SYSMAN"
  description                     = "System Management - Function: c3 - VLAN: 3195"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_sysman_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_sysman.name
  ip            = "2609:efff:b33b:c300::1/64"
  scope         = "public"
  shared        = false
}



resource "mso_schema_template_anp_epg" "epg_sysman" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-SYSMAN"
  display_name  = "EPG-SYSMAN"
  bd_name       = mso_schema_template_bd.bd_sysman.name
}


# ============================================================================
# Function: c6 - ACAS-MGMT | IPv6: 2609:efff:b33b:c600::1/64 | VLAN: 3198 ✅
# ============================================================================


resource "mso_schema_template_bd" "bd_acas_mgmt" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-ACAS-MGMT"
  display_name                    = "BD-ACAS-MGMT"
  description                     = "ACAS Management - Function: c6 - VLAN: 3198"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_acas_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_acas_mgmt.name
  ip            = "2609:efff:b33b:c600::1/64"
  scope         = "public"
  shared        = false
}



resource "mso_schema_template_anp_epg" "epg_acas_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-ACAS-MGMT"
  display_name  = "EPG-ACAS-MGMT"
  bd_name       = mso_schema_template_bd.bd_acas_mgmt.name
}


# ============================================================================
# Function: e6 - PATCH | IPv6: 2609:efff:b33b:e600::1/64 | VLAN: 3230 ✅
# ============================================================================


resource "mso_schema_template_bd" "bd_patch" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-PATCH"
  display_name                    = "BD-PATCH"
  description                     = "Patch Management - Function: e6 - VLAN: 3230"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = true
  optimize_wan_bandwidth          = true
  arp_flooding                    = true
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_patch_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_patch.name
  ip            = "2609:efff:b33b:e600::1/64"
  scope         = "public"
  shared        = false
}



resource "mso_schema_template_anp_epg" "epg_patch" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-PATCH"
  display_name  = "EPG-PATCH"
  bd_name       = mso_schema_template_bd.bd_patch.name
}


# ============================================================================
# SITE ASSOCIATIONS - Stretched_Services
# ============================================================================

resource "mso_schema_site_anp" "site_anp_site1_stretched" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
}

resource "mso_schema_site_anp" "site_anp_site2_stretched" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
}

# Site EPGs - Site1 (showing all 29)
resource "mso_schema_site_anp_epg" "site_epg_nac_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_nac.name
}

resource "mso_schema_site_anp_epg" "site_epg_cfg_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_cfg_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_mecm_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_mecm.name
}

resource "mso_schema_site_anp_epg" "site_epg_lb_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_lb.name
}

resource "mso_schema_site_anp_epg" "site_epg_dns_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_dns_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_dns_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_dns.name
}

resource "mso_schema_site_anp_epg" "site_epg_dhcp_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_dhcp_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_smtp_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_smtp_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_vvoip_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_vvoip_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vvoip_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_lmr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_lmr.name
}

resource "mso_schema_site_anp_epg" "site_epg_e911_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_e911_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_acas_scanners_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_acas_scanners.name
}

resource "mso_schema_site_anp_epg" "site_epg_c2c_scanners_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_c2c_scanners.name
}

resource "mso_schema_site_anp_epg" "site_epg_ocsp_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_ocsp.name
}

resource "mso_schema_site_anp_epg" "site_epg_pki_srv_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_pki_srv.name
}

resource "mso_schema_site_anp_epg" "site_epg_ad_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_ad.name
}

resource "mso_schema_site_anp_epg" "site_epg_adfs_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_adfs.name
}

resource "mso_schema_site_anp_epg" "site_epg_d64_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_d64_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_rweb_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rweb_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_fweb_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_fweb_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_app_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_app_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_web_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_web_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_fmwr_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_fmwr_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_dco_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_dco.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_unix_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_unix.name
}

resource "mso_schema_site_anp_epg" "site_epg_print_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_print_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_file_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_file_svr.name
}


resource "mso_schema_site_anp_epg" "site_epg_nms_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_nms.name
}



resource "mso_schema_site_anp_epg" "site_epg_vhost_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vhost_mgmt.name
}



resource "mso_schema_site_anp_epg" "site_epg_adm_dco_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_adm_dco.name
}



resource "mso_schema_site_anp_epg" "site_epg_sysman_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_sysman.name
}



resource "mso_schema_site_anp_epg" "site_epg_acas_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_acas_mgmt.name
}



resource "mso_schema_site_anp_epg" "site_epg_patch_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_patch.name
}


# Site EPGs - Site2 (all 29 - identical structure for K site)
resource "mso_schema_site_anp_epg" "site_epg_nac_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_nac.name
}

resource "mso_schema_site_anp_epg" "site_epg_cfg_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_cfg_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_mecm_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_mecm.name
}

resource "mso_schema_site_anp_epg" "site_epg_lb_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_lb.name
}

resource "mso_schema_site_anp_epg" "site_epg_dns_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_dns_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_dns_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_dns.name
}

resource "mso_schema_site_anp_epg" "site_epg_dhcp_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_dhcp_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_smtp_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_smtp_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_vvoip_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_vvoip_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vvoip_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_lmr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_lmr.name
}

resource "mso_schema_site_anp_epg" "site_epg_e911_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_e911_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_acas_scanners_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_acas_scanners.name
}

resource "mso_schema_site_anp_epg" "site_epg_c2c_scanners_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_c2c_scanners.name
}

resource "mso_schema_site_anp_epg" "site_epg_ocsp_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_ocsp.name
}

resource "mso_schema_site_anp_epg" "site_epg_pki_srv_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_pki_srv.name
}

resource "mso_schema_site_anp_epg" "site_epg_ad_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_ad.name
}

resource "mso_schema_site_anp_epg" "site_epg_adfs_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_adfs.name
}

resource "mso_schema_site_anp_epg" "site_epg_d64_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_d64_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_rweb_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rweb_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_fweb_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_fweb_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_app_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_app_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_web_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_web_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_fmwr_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_fmwr_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_dco_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_dco.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_unix_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_unix.name
}

resource "mso_schema_site_anp_epg" "site_epg_print_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_print_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_file_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_file_svr.name
}


resource "mso_schema_site_anp_epg" "site_epg_nms_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_nms.name
}



resource "mso_schema_site_anp_epg" "site_epg_vhost_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vhost_mgmt.name
}



resource "mso_schema_site_anp_epg" "site_epg_adm_dco_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_adm_dco.name
}



resource "mso_schema_site_anp_epg" "site_epg_sysman_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_sysman.name
}



resource "mso_schema_site_anp_epg" "site_epg_acas_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_acas_mgmt.name
}



resource "mso_schema_site_anp_epg" "site_epg_patch_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_patch.name
}


# ============================================================================
# G-SPECIFIC_ONLY TEMPLATE
# ============================================================================

resource "mso_schema_template_anp" "appprof_rcc_g_specific" {
  schema_id    = data.mso_schema.existing.id
  template     = "Kelley_Unique"
  name         = "AppProf-AFR-PROD-V6"
  display_name = "AppProf-AFR-PROD-V6"
}

# Function: ef - GEF-MGMT | IPv6: 2609:efff:b33b:ef00::1/64 | VLAN: Safe range
resource "mso_schema_template_bd" "bd_gef_mgmt" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Kelley_Unique"
  name                            = "BD-GEF-MGMT"
  display_name                    = "BD-GEF-MGMT"
  description                     = "GEF Management - Function: ef - G-Site Only"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = false
  optimize_wan_bandwidth          = false
  arp_flooding                    = false
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_gef_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Kelley_Unique"
  bd_name       = mso_schema_template_bd.bd_gef_mgmt.name
  ip            = "2609:efff:b33b:ef00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_gef_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Kelley_Unique"
  anp_name      = mso_schema_template_anp.appprof_rcc_g_specific.name
  name          = "EPG-GEF-MGMT"
  display_name  = "EPG-GEF-MGMT"
  bd_name       = mso_schema_template_bd.bd_gef_mgmt.name
}

resource "mso_schema_site_anp" "site_anp_site1_g_specific" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Kelley_Unique"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_g_specific.name
}

resource "mso_schema_site_anp_epg" "site_epg_gef_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Kelley_Unique"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_g_specific.name
  epg_name      = mso_schema_template_anp_epg.epg_gef_mgmt.name
}

# ============================================================================
# K-SPECIFIC_ONLY TEMPLATE
# ============================================================================

resource "mso_schema_template_anp" "appprof_rcc_k_specific" {
  schema_id    = data.mso_schema.existing.id
  template     = "Del_Din_Unique"
  name         = "AppProf-AFR-PROD-V6"
  display_name = "AppProf-AFR-PROD-V6"
}

# Function: dd - BACKUP-SVR | IPv6: 2609:efff:b33b:dd00::1/64 | VLAN: 3221 ✅
resource "mso_schema_template_bd" "bd_backup_svr_k" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Del_Din_Unique"
  name                            = "BD-BACKUP-SVR"
  display_name                    = "BD-BACKUP-SVR"
  description                     = "Backup Server - Function: dd - VLAN: 3221 - K-Site Only"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = false
  optimize_wan_bandwidth          = false
  arp_flooding                    = false
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_backup_svr_k_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Del_Din_Unique"
  bd_name       = mso_schema_template_bd.bd_backup_svr_k.name
  ip            = "2609:efff:b33b:dd00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_backup_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Del_Din_Unique"
  anp_name      = mso_schema_template_anp.appprof_rcc_k_specific.name
  name          = "EPG-BACKUP-SVR"
  display_name  = "EPG-BACKUP-SVR"
  bd_name       = mso_schema_template_bd.bd_backup_svr_k.name
}

resource "mso_schema_site_anp" "site_anp_site2_k_specific" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Del_Din_Unique"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_k_specific.name
}

resource "mso_schema_site_anp_epg" "site_epg_backup_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Del_Din_Unique"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_k_specific.name
  epg_name      = mso_schema_template_anp_epg.epg_backup_svr_k.name
}

# ============================================================================
# L2_NON-STRETCHED TEMPLATE
# ============================================================================

# Function: db - DB-SVR | IPv6: 2609:efff:b33b:db00::1/64 | VLAN: 3219 ✅
resource "mso_schema_template_bd" "bd_db_svr" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-DB-SVR"
  display_name                    = "BD-DB-SVR"
  description                     = "Database Server - Function: db - VLAN: 3219 - Site-Local"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = false
  optimize_wan_bandwidth          = false
  arp_flooding                    = false
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_db_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_db_svr.name
  ip            = "2609:efff:b33b:db00::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_db_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-DB-SVR"
  display_name  = "EPG-DB-SVR"
  bd_name       = mso_schema_template_bd.bd_db_svr.name
}

# Function: d9 - SYSLOG | IPv6: 2609:efff:b33b:d900::1/64 | VLAN: 3217 ✅
resource "mso_schema_template_bd" "bd_syslog" {
  schema_id                       = data.mso_schema.existing.id
  template_name                   = "Stretched_Services"
  name                            = "BD-SYSLOG"
  display_name                    = "BD-SYSLOG"
  description                     = "System Logging - Function: d9 - VLAN: 3217 - Site-Local"
  vrf_name                        = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id                   = data.mso_schema.existing.id
  vrf_template_name               = var.vrf_template_name
  layer2_unknown_unicast          = "proxy"
  layer2_stretch                  = true
  unicast_routing                 = true
  intersite_bum_traffic           = false
  optimize_wan_bandwidth          = false
  arp_flooding                    = false
  unknown_multicast_flooding      = "flood"
  ipv6_unknown_multicast_flooding = "flood"

}

resource "mso_schema_template_bd_subnet" "bd_syslog_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  bd_name       = mso_schema_template_bd.bd_syslog.name
  ip            = "2609:efff:b33b:d900::1/64"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_syslog" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-SYSLOG"
  display_name  = "EPG-SYSLOG"
  bd_name       = mso_schema_template_bd.bd_syslog.name
}

# Site Associations - Site-Local services (ANP added via site_anp_site1_stretched)
resource "mso_schema_site_anp_epg" "site_epg_db_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_db_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_syslog_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_syslog.name
}

resource "mso_schema_site_anp_epg" "site_epg_db_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_db_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_syslog_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_syslog.name
}

# ============================================================================
# SITE BD CONFIGURATIONS - Host Route Enabled
# ============================================================================

# Stretched_Services BDs - Site1 Site (29 BDs)
resource "mso_schema_site_bd" "bd_nac_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_nac.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_cfg_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_cfg_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_mecm_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_mecm.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_lb_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_lb.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_dns_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_dns_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_dns_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_dns.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_dhcp_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_dhcp_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_smtp_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_smtp_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_vvoip_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vvoip_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_vvoip_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vvoip_proxy.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_lmr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_lmr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_e911_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_e911_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_acas_scanners_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_acas_scanners.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_c2c_scanners_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_c2c_scanners.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_ocsp_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_ocsp.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_pki_srv_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_pki_srv.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_ad_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_ad.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_adfs_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_adfs.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_d64_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_d64_proxy.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rweb_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rweb_proxy.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_fweb_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_fweb_proxy.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_app_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_app_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_web_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_web_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_fmwr_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_fmwr_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_dco_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_dco.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_unix_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_unix.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_print_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_print_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_file_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_file_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}


resource "mso_schema_site_bd" "bd_nms_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_nms.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_vhost_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vhost_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_adm_dco_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_adm_dco.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_sysman_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_sysman.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_acas_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_acas_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_patch_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_patch.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}


# Stretched_Services BDs - Site2 Site (29 BDs - same structure)
resource "mso_schema_site_bd" "bd_nac_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_nac.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_cfg_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_cfg_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_mecm_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_mecm.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_lb_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_lb.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_dns_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_dns_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_dns_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_dns.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_dhcp_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_dhcp_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_smtp_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_smtp_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_vvoip_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vvoip_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_vvoip_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vvoip_proxy.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_lmr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_lmr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_e911_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_e911_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_acas_scanners_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_acas_scanners.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_c2c_scanners_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_c2c_scanners.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_ocsp_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_ocsp.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_pki_srv_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_pki_srv.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_ad_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_ad.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_adfs_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_adfs.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_d64_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_d64_proxy.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rweb_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rweb_proxy.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_fweb_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_fweb_proxy.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_app_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_app_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_web_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_web_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_fmwr_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_fmwr_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_dco_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_dco.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_unix_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_unix.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_print_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_print_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_file_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_file_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}


resource "mso_schema_site_bd" "bd_nms_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_nms.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_vhost_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vhost_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_adm_dco_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_adm_dco.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_sysman_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_sysman.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_acas_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_acas_mgmt.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}



resource "mso_schema_site_bd" "bd_patch_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_patch.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}


# G-Specific and K-Specific BDs
resource "mso_schema_site_bd" "bd_gef_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_gef_mgmt.name
  template_name = "Kelley_Unique"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_backup_svr_k_site" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_backup_svr_k.name
  template_name = "Del_Din_Unique"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

# Stretched_Services (was L2_Non-Stretched) BDs - Both Sites
resource "mso_schema_site_bd" "bd_db_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_db_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_db_svr_k_site" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_db_svr.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_syslog_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_syslog.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_syslog_k_site" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_syslog.name
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  host_route    = true
}

# ============================================================================
# VMM DOMAIN ASSOCIATIONS - All EPGs
# Per-fabric VMware VMM domains: Kelley-VDS1 (Site1/Kelley), Del-Din-VDS1 (Site2/Del-Din)
# ============================================================================

# Stretched_Services EPGs - Site1 (29 domains)
resource "mso_schema_site_anp_epg_domain" "epg_nac_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_nac.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_nac_g]
}


resource "mso_schema_site_anp_epg_domain" "epg_cfg_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_cfg_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_cfg_mgmt_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_mecm_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_mecm.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_mecm_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_lb_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_lb.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_lb_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_dns_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_dns_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_dns_mgmt_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dns_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_dns.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_dns_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_dhcp_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_dhcp_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_dhcp_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_smtp_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_smtp_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_smtp_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vvoip_mgmt_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_proxy_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vvoip_proxy.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vvoip_proxy_g]
}

# COMMENTED OUT - Domain association already exists in NDO
# resource "mso_schema_site_anp_epg_domain" "epg_lmr_domain_g" {
#   schema_id            = data.mso_schema.existing.id
#   template_name        = "Stretched_Services"
#   site_id              = data.mso_site.site1.id
#   anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
#   epg_name             = mso_schema_template_anp_epg.epg_lmr.name
#   domain_type          = "physicalDomain"
#   domain_name          = "PhysDom_ACI_IPv6"
#   deploy_immediacy     = "immediate"
#   resolution_immediacy = "immediate"
#   depends_on           = [mso_schema_site_anp_epg.site_epg_lmr_g]
# }

resource "mso_schema_site_anp_epg_domain" "epg_e911_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_e911_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_e911_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_acas_scanners_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_acas_scanners.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_acas_scanners_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_c2c_scanners_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_c2c_scanners.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_c2c_scanners_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_ocsp_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_ocsp.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_ocsp_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_pki_srv_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_pki_srv.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_pki_srv_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_ad_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_ad.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_ad_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_adfs_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_adfs.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_adfs_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_d64_proxy_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_d64_proxy.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_d64_proxy_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rweb_proxy_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rweb_proxy.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rweb_proxy_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_fweb_proxy_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_fweb_proxy.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_fweb_proxy_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_app_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_app_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_app_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_web_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_web_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_web_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_fmwr_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_fmwr_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_fmwr_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dco_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_dco.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_dco_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_unix_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_unix.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_unix_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_print_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_print_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_print_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_file_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_file_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_file_svr_g]
}


resource "mso_schema_site_anp_epg_domain" "epg_nms_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_nms.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_nms_g]
}



resource "mso_schema_site_anp_epg_domain" "epg_vhost_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vhost_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vhost_mgmt_g]
}



resource "mso_schema_site_anp_epg_domain" "epg_adm_dco_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_adm_dco.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_adm_dco_g]
}



resource "mso_schema_site_anp_epg_domain" "epg_sysman_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_sysman.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_sysman_g]
}



resource "mso_schema_site_anp_epg_domain" "epg_acas_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_acas_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_acas_mgmt_g]
}



resource "mso_schema_site_anp_epg_domain" "epg_patch_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_patch.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_patch_g]
}


# Stretched_Services EPGs - Site2 (29 domains - identical structure)
resource "mso_schema_site_anp_epg_domain" "epg_nac_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_nac.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_nac_k]
}


resource "mso_schema_site_anp_epg_domain" "epg_cfg_mgmt_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_cfg_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_cfg_mgmt_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_mecm_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_mecm.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_mecm_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_lb_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_lb.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_lb_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_dns_mgmt_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_dns_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_dns_mgmt_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dns_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_dns.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_dns_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_dhcp_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_dhcp_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_dhcp_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_smtp_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_smtp_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_smtp_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_mgmt_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vvoip_mgmt_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_proxy_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vvoip_proxy.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vvoip_proxy_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_lmr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_lmr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_lmr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_e911_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_e911_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_e911_svr_k]
}

# COMMENTED OUT - Domain association already exists in NDO
# resource "mso_schema_site_anp_epg_domain" "epg_acas_scanners_domain_k" {
#   schema_id            = data.mso_schema.existing.id
#   template_name        = "Stretched_Services"
#   site_id              = data.mso_site.site2.id
#   anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
#   epg_name             = mso_schema_template_anp_epg.epg_acas_scanners.name
#   domain_type          = "physicalDomain"
#   domain_name          = "PhysDom_ACI_IPv6"
#   deploy_immediacy     = "immediate"
#   resolution_immediacy = "immediate"
#   depends_on           = [mso_schema_site_anp_epg.site_epg_acas_scanners_k]
# }

resource "mso_schema_site_anp_epg_domain" "epg_c2c_scanners_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_c2c_scanners.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_c2c_scanners_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_ocsp_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_ocsp.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_ocsp_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_pki_srv_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_pki_srv.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_pki_srv_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_ad_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_ad.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_ad_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_adfs_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_adfs.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_adfs_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_d64_proxy_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_d64_proxy.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_d64_proxy_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rweb_proxy_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rweb_proxy.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rweb_proxy_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_fweb_proxy_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_fweb_proxy.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_fweb_proxy_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_app_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_app_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_app_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_web_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_web_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_web_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_fmwr_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_fmwr_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_fmwr_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dco_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_dco.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_dco_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_unix_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_unix.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_unix_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_print_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_print_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_print_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_file_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_file_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_file_svr_k]
}


resource "mso_schema_site_anp_epg_domain" "epg_nms_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_nms.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_nms_k]
}



resource "mso_schema_site_anp_epg_domain" "epg_vhost_mgmt_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vhost_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vhost_mgmt_k]
}



resource "mso_schema_site_anp_epg_domain" "epg_adm_dco_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_adm_dco.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_adm_dco_k]
}



resource "mso_schema_site_anp_epg_domain" "epg_sysman_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_sysman.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_sysman_k]
}



resource "mso_schema_site_anp_epg_domain" "epg_acas_mgmt_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_acas_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_acas_mgmt_k]
}



resource "mso_schema_site_anp_epg_domain" "epg_patch_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_patch.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_patch_k]
}


# Kelley_Unique EPG Domain
resource "mso_schema_site_anp_epg_domain" "epg_gef_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Kelley_Unique"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_g_specific.name
  epg_name             = mso_schema_template_anp_epg.epg_gef_mgmt.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_gef_mgmt_g]
}

# Del_Din_Unique EPG Domain
resource "mso_schema_site_anp_epg_domain" "epg_backup_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Del_Din_Unique"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_k_specific.name
  epg_name             = mso_schema_template_anp_epg.epg_backup_svr_k.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_backup_svr_k]
}

# Stretched_Services (was L2_Non-Stretched) EPG Domains - Site1
resource "mso_schema_site_anp_epg_domain" "epg_db_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_db_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_db_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_syslog_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site1.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_syslog.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Kelley-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_syslog_g]
}

# Stretched_Services (was L2_Non-Stretched) EPG Domains - Site2
resource "mso_schema_site_anp_epg_domain" "epg_db_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_db_svr.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_db_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_syslog_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "Stretched_Services"
  site_id              = data.mso_site.site2.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_syslog.name
  domain_type          = "vmmDomain"
  vmm_domain_type      = "VMware"
  domain_name          = "Del-Din-VDS1"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_syslog_k]
}
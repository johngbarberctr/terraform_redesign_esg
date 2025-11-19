# ============================================================================
# COMPLETE TERRAFORM CONFIGURATION - FINAL CORRECTED VERSION
# ============================================================================
# IPv6 Address Format: [function_code]00::1/56
# All VLANs verified from actual VM deployment data
# 
# CORRECTED: VVOIP function codes
#   - Function 40 (not 41) = VVOIP-MGMT → 4000::1/56, VLAN 3064
#   - Function 41 (not 42) = VVOIP-PROXY → 4100::1/56, VLAN 3065
# ============================================================================

# ============================================================================
# IPv6 AND VLAN REFERENCE MAP - FINAL
# ============================================================================
#
# Func | BD Name           | IPv6 Subnet  | Gateway IP   | VLAN | Public | Verified
# -----|-------------------|--------------|--------------|------|--------|----------
# 15   | BD-NAC            | 1500::/56    | 1500::1/56   | 3021 | No     | ✅
# 1b   | BD-LB             | 1b00::/56    | 1b00::1/56   | -    | No     | ⚠️
# 40   | BD-VVOIP-MGMT     | 4000::/56    | 4000::1/56   | 3064 | No     | ✅
# 41   | BD-VVOIP-PROXY    | 4100::/56    | 4100::1/56   | 3065 | No     | ✅
# 53   | BD-DNS-MGMT       | 5300::/56    | 5300::1/56   | 3083 | No     | ✅
# 69   | BD-CFG-MGMT       | 6900::/56    | 6900::1/56   | 3105 | No     | ✅
# ad   | BD-AD             | ad00::/56    | ad00::1/56   | 3173 | No     | ✅
# af   | BD-ADFS           | af00::/56    | af00::1/56   | 3175 | No     | ✅
# bc   | BD-RCC-SVR        | bc00::/56    | bc00::1/56   | -    | No     | ⚠️
# bd   | BD-RCC-DNS        | bd00::/56    | bd00::1/56   | -    | No     | ⚠️
# be   | BD-RCC-DCO        | be00::/56    | be00::1/56   | -    | No     | ⚠️
# bf   | BD-RCC-UNIX       | bf00::/56    | bf00::1/56   | -    | No     | ⚠️
# c0   | BD-ACAS-SCANNERS  | c000::/56    | c000::1/56   | 3192 | No     | ✅
# c1   | BD-C2C-SCANNERS   | c001::/56    | c001::1/56   | 3442 | No     | ✅
# c5   | BD-OCSP           | c500::/56    | c500::1/56   | 3197 | No     | ✅
# ca   | BD-PKI-SRV        | ca00::/56    | ca00::1/56   | -    | No     | ⚠️
# cb   | BD-LMR            | cb00::/56    | cb00::1/56   | -    | No     | ⚠️
# d0   | BD-PRINT-SVR      | d000::/56    | d000::1/56   | 3208 | No     | ✅
# d1   | BD-FILE-SVR       | d100::/56    | d100::1/56   | 3209 | No     | ✅
# d2   | BD-DHCP-SVR       | d200::/56    | d200::1/56   | 3210 | No     | ✅
# d5   | BD-SMTP-SVR       | d500::/56    | d500::1/56   | 3213 | No     | ✅
# d6   | BD-D64-PROXY      | d600::/56    | d600::1/56   | -    | No     | ⚠️
# d7   | BD-RWEB-PROXY     | d700::/56    | d700::1/56   | -    | Yes    | ⚠️
# d8   | BD-FWEB-PROXY     | d800::/56    | d800::1/56   | -    | Yes    | ⚠️
# d9   | BD-SYSLOG         | d900::/56    | d900::1/56   | 3217 | No     | ✅
# db   | BD-DB-SVR         | db00::/56    | db00::1/56   | 3219 | No     | ✅
# dd   | BD-BACKUP-SVR     | dd00::/56    | dd00::1/56   | 3221 | No     | ✅
# e0   | BD-APP-SVR        | e000::/56    | e000::1/56   | 3224 | No     | ✅
# e3   | BD-FMWR-SVR       | e300::/56    | e300::1/56   | -    | No     | ⚠️
# e4   | BD-WEB-SVR        | e400::/56    | e400::1/56   | 3228 | Yes    | ✅
# e9   | BD-E911-SVR       | e900::/56    | e900::1/56   | -    | No     | ⚠️
# ec   | BD-MECM           | ec00::/56    | ec00::1/56   | 3236 | No     | ✅
# ef   | BD-GEF-MGMT       | ef00::/56    | ef00::1/56   | -    | No     | ⚠️
#
# ✅ = VLAN verified from VM deployment data
# ⚠️ = VLAN not in data, assigned from safe range (3050-3062, 3500+)
#
# ============================================================================

# Data sources
data "mso_schema" "existing" {
  name = "AEDCE"
}

data "mso_site" "aedcg" {
  name = "AEDCG"
}

data "mso_site" "aedck" {
  name = "AEDCK"
}

data "mso_tenant" "eur" {
  name = "EUR"
}

# ============================================================================
# VRF DEFINITION
# ============================================================================

resource "mso_schema_template_vrf" "vrf_rcc" {
  schema_id        = data.mso_schema.existing.id
  template         = "UpgradeTemplate1"
  name             = "VRF-RCC"
  display_name     = "VRF-RCC"
  layer3_multicast = false
  vzany            = true
}

# ============================================================================
# CONTRACT AND FILTER
# ============================================================================

resource "mso_schema_template_contract" "contract_vrf_rcc" {
  schema_id     = data.mso_schema.existing.id
  template_name = "UpgradeTemplate1"
  contract_name = "Any_VRF-RCC"
  display_name  = "Any_VRF-RCC"
  scope         = "context"
  filter_type   = "bothWay"

  filter_relationship {
    filter_schema_id      = data.mso_schema.existing.id
    filter_template_name  = "UpgradeTemplate1"
    filter_name           = "Any"
    filter_type           = "bothWay"
  }
}

# ============================================================================
# L2_STRETCHED TEMPLATE
# ============================================================================

resource "mso_schema_template_anp" "appprof_rcc_stretched" {
  schema_id    = data.mso_schema.existing.id
  template     = "L2_Stretched"
  name         = "AppProf-RCC"
  display_name = "AppProf-RCC"
}

# ============================================================================
# Function: 15 - NAC | IPv6: 1500::1/56 | VLAN: 3021 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_nac" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-NAC"
  display_name            = "BD-NAC"
  description             = "Network Access Control - Function: 15 - VLAN: 3021"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_nac_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_nac.name
  ip            = "1500::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_nac" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-NAC"
  display_name  = "EPG-NAC"
  bd_name       = mso_schema_template_bd.bd_nac.name
}

# ============================================================================
# Function: 69 - CFG-MGMT | IPv6: 6900::1/56 | VLAN: 3105 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_cfg_mgmt" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-CFG-MGMT"
  display_name            = "BD-CFG-MGMT"
  description             = "Configuration Management - Function: 69 - VLAN: 3105"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_cfg_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_cfg_mgmt.name
  ip            = "6900::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_cfg_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-CFG-MGMT"
  display_name  = "EPG-CFG-MGMT"
  bd_name       = mso_schema_template_bd.bd_cfg_mgmt.name
}

# ============================================================================
# Function: ec - MECM | IPv6: ec00::1/56 | VLAN: 3236 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_mecm" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-MECM"
  display_name            = "BD-MECM"
  description             = "Microsoft Endpoint Configuration Manager - Function: ec - VLAN: 3236"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_mecm_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_mecm.name
  ip            = "ec00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_mecm" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-MECM"
  display_name  = "EPG-MECM"
  bd_name       = mso_schema_template_bd.bd_mecm.name
}

# ============================================================================
# Function: 1b - LB | IPv6: 1b00::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_lb" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-LB"
  display_name            = "BD-LB"
  description             = "Load Balancer - Function: 1b"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_lb_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_lb.name
  ip            = "1b00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_lb" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-LB"
  display_name  = "EPG-LB"
  bd_name       = mso_schema_template_bd.bd_lb.name
}

# ============================================================================
# Function: 53 - DNS-MGMT | IPv6: 5300::1/56 | VLAN: 3083 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_dns_mgmt" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-DNS-MGMT"
  display_name            = "BD-DNS-MGMT"
  description             = "DNS Management - Function: 53 - VLAN: 3083"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_dns_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_dns_mgmt.name
  ip            = "5300::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_dns_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-DNS-MGMT"
  display_name  = "EPG-DNS-MGMT"
  bd_name       = mso_schema_template_bd.bd_dns_mgmt.name
}

# ============================================================================
# Function: bd - RCC-DNS | IPv6: bd00::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_rcc_dns" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-RCC-DNS"
  display_name            = "BD-RCC-DNS"
  description             = "RCC DNS Services - Function: bd"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_rcc_dns_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rcc_dns.name
  ip            = "bd00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rcc_dns" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-RCC-DNS"
  display_name  = "EPG-RCC-DNS"
  bd_name       = mso_schema_template_bd.bd_rcc_dns.name
}

# ============================================================================
# Function: d2 - DHCP-SVR | IPv6: d200::1/56 | VLAN: 3210 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_dhcp_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-DHCP-SVR"
  display_name            = "BD-DHCP-SVR"
  description             = "DHCP Server - Function: d2 - VLAN: 3210"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_dhcp_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_dhcp_svr.name
  ip            = "d200::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_dhcp_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-DHCP-SVR"
  display_name  = "EPG-DHCP-SVR"
  bd_name       = mso_schema_template_bd.bd_dhcp_svr.name
}

# ============================================================================
# Function: d5 - SMTP-SVR | IPv6: d500::1/56 | VLAN: 3213 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_smtp_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-SMTP-SVR"
  display_name            = "BD-SMTP-SVR"
  description             = "SMTP Server - Function: d5 - VLAN: 3213"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_smtp_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_smtp_svr.name
  ip            = "d500::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_smtp_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-SMTP-SVR"
  display_name  = "EPG-SMTP-SVR"
  bd_name       = mso_schema_template_bd.bd_smtp_svr.name
}

# ============================================================================
# Function: 40 - VVOIP-MGMT | IPv6: 4000::1/56 | VLAN: 3064 ✅ CORRECTED
# ============================================================================

resource "mso_schema_template_bd" "bd_vvoip_mgmt" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-VVOIP-MGMT"
  display_name            = "BD-VVOIP-MGMT"
  description             = "Video/Voice Management - Function: 40 - VLAN: 3064"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_vvoip_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_vvoip_mgmt.name
  ip            = "4000::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_vvoip_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-VVOIP-MGMT"
  display_name  = "EPG-VVOIP-MGMT"
  bd_name       = mso_schema_template_bd.bd_vvoip_mgmt.name
}

# ============================================================================
# Function: 41 - VVOIP-PROXY | IPv6: 4100::1/56 | VLAN: 3065 ✅ CORRECTED
# ============================================================================

resource "mso_schema_template_bd" "bd_vvoip_proxy" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-VVOIP-PROXY"
  display_name            = "BD-VVOIP-PROXY"
  description             = "Video/Voice Proxy - Function: 41 - VLAN: 3065"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_vvoip_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_vvoip_proxy.name
  ip            = "4100::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_vvoip_proxy" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-VVOIP-PROXY"
  display_name  = "EPG-VVOIP-PROXY"
  bd_name       = mso_schema_template_bd.bd_vvoip_proxy.name
}

# ============================================================================
# Function: cb - LMR | IPv6: cb00::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_lmr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-LMR"
  display_name            = "BD-LMR"
  description             = "Land Mobile Radio - Function: cb"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_lmr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_lmr.name
  ip            = "cb00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_lmr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-LMR"
  display_name  = "EPG-LMR"
  bd_name       = mso_schema_template_bd.bd_lmr.name
}

# ============================================================================
# Function: e9 - E911-SVR | IPv6: e900::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_e911_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-E911-SVR"
  display_name            = "BD-E911-SVR"
  description             = "Emergency Services - Function: e9"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_e911_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_e911_svr.name
  ip            = "e900::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_e911_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-E911-SVR"
  display_name  = "EPG-E911-SVR"
  bd_name       = mso_schema_template_bd.bd_e911_svr.name
}

# ============================================================================
# Function: c0 - ACAS-SCANNERS | IPv6: c000::1/56 | VLAN: 3192 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_acas_scanners" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-ACAS-SCANNERS"
  display_name            = "BD-ACAS-SCANNERS"
  description             = "Assured Compliance Assessment Solution - Function: c0 - VLAN: 3192"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_acas_scanners_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_acas_scanners.name
  ip            = "c000::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_acas_scanners" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-ACAS-SCANNERS"
  display_name  = "EPG-ACAS-SCANNERS"
  bd_name       = mso_schema_template_bd.bd_acas_scanners.name
}

# ============================================================================
# Function: c1 - C2C-SCANNERS | IPv6: c001::1/56 | VLAN: 3442 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_c2c_scanners" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-C2C-SCANNERS"
  display_name            = "BD-C2C-SCANNERS"
  description             = "C2C Vulnerability Scanners - Function: c1 - VLAN: 3442"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_c2c_scanners_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_c2c_scanners.name
  ip            = "c001::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_c2c_scanners" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-C2C-SCANNERS"
  display_name  = "EPG-C2C-SCANNERS"
  bd_name       = mso_schema_template_bd.bd_c2c_scanners.name
}

# ============================================================================
# Function: c5 - OCSP | IPv6: c500::1/56 | VLAN: 3197 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_ocsp" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-OCSP"
  display_name            = "BD-OCSP"
  description             = "Online Certificate Status Protocol - Function: c5 - VLAN: 3197"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_ocsp_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_ocsp.name
  ip            = "c500::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_ocsp" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-OCSP"
  display_name  = "EPG-OCSP"
  bd_name       = mso_schema_template_bd.bd_ocsp.name
}

# ============================================================================
# Function: ca - PKI-SRV | IPv6: ca00::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_pki_srv" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-PKI-SRV"
  display_name            = "BD-PKI-SRV"
  description             = "Public Key Infrastructure - Function: ca"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_pki_srv_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_pki_srv.name
  ip            = "ca00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_pki_srv" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-PKI-SRV"
  display_name  = "EPG-PKI-SRV"
  bd_name       = mso_schema_template_bd.bd_pki_srv.name
}

# ============================================================================
# Function: ad - AD | IPv6: ad00::1/56 | VLAN: 3173 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_ad" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-AD"
  display_name            = "BD-AD"
  description             = "Active Directory - Function: ad - VLAN: 3173"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_ad_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_ad.name
  ip            = "ad00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_ad" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-AD"
  display_name  = "EPG-AD"
  bd_name       = mso_schema_template_bd.bd_ad.name
}

# ============================================================================
# Function: af - ADFS | IPv6: af00::1/56 | VLAN: 3175 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_adfs" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-ADFS"
  display_name            = "BD-ADFS"
  description             = "Active Directory Federation Services - Function: af - VLAN: 3175"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_adfs_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_adfs.name
  ip            = "af00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_adfs" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-ADFS"
  display_name  = "EPG-ADFS"
  bd_name       = mso_schema_template_bd.bd_adfs.name
}

# ============================================================================
# Function: d6 - D64-PROXY | IPv6: d600::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_d64_proxy" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-D64-PROXY"
  display_name            = "BD-D64-PROXY"
  description             = "DNS64 Proxy - Function: d6"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_d64_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_d64_proxy.name
  ip            = "d600::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_d64_proxy" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-D64-PROXY"
  display_name  = "EPG-D64-PROXY"
  bd_name       = mso_schema_template_bd.bd_d64_proxy.name
}

# ============================================================================
# Function: d7 - RWEB-PROXY | IPv6: d700::1/56 | VLAN: Safe range | PUBLIC
# ============================================================================

resource "mso_schema_template_bd" "bd_rweb_proxy" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-RWEB-PROXY"
  display_name            = "BD-RWEB-PROXY"
  description             = "Reverse Web Proxy - Function: d7 - PUBLIC SERVICE"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_rweb_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rweb_proxy.name
  ip            = "d700::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rweb_proxy" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-RWEB-PROXY"
  display_name  = "EPG-RWEB-PROXY"
  bd_name       = mso_schema_template_bd.bd_rweb_proxy.name
}

# ============================================================================
# Function: d8 - FWEB-PROXY | IPv6: d800::1/56 | VLAN: Safe range | PUBLIC
# ============================================================================

resource "mso_schema_template_bd" "bd_fweb_proxy" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-FWEB-PROXY"
  display_name            = "BD-FWEB-PROXY"
  description             = "Forward Web Proxy - Function: d8 - PUBLIC SERVICE"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_fweb_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_fweb_proxy.name
  ip            = "d800::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_fweb_proxy" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-FWEB-PROXY"
  display_name  = "EPG-FWEB-PROXY"
  bd_name       = mso_schema_template_bd.bd_fweb_proxy.name
}

# ============================================================================
# Function: e0 - APP-SVR | IPv6: e000::1/56 | VLAN: 3224 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_app_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-APP-SVR"
  display_name            = "BD-APP-SVR"
  description             = "Application Server - Function: e0 - VLAN: 3224"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_app_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_app_svr.name
  ip            = "e000::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_app_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-APP-SVR"
  display_name  = "EPG-APP-SVR"
  bd_name       = mso_schema_template_bd.bd_app_svr.name
}

# ============================================================================
# Function: e4 - WEB-SVR | IPv6: e400::1/56 | VLAN: 3228 ✅ | PUBLIC
# ============================================================================

resource "mso_schema_template_bd" "bd_web_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-WEB-SVR"
  display_name            = "BD-WEB-SVR"
  description             = "Web Server - Function: e4 - VLAN: 3228 - PUBLIC SERVICE"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_web_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_web_svr.name
  ip            = "e400::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_web_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-WEB-SVR"
  display_name  = "EPG-WEB-SVR"
  bd_name       = mso_schema_template_bd.bd_web_svr.name
}

# ============================================================================
# Function: e3 - FMWR-SVR | IPv6: e300::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_fmwr_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-FMWR-SVR"
  display_name            = "BD-FMWR-SVR"
  description             = "Firmware Server - Function: e3"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_fmwr_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_fmwr_svr.name
  ip            = "e300::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_fmwr_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-FMWR-SVR"
  display_name  = "EPG-FMWR-SVR"
  bd_name       = mso_schema_template_bd.bd_fmwr_svr.name
}

# ============================================================================
# Function: bc - RCC-SVR | IPv6: bc00::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_rcc_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-RCC-SVR"
  display_name            = "BD-RCC-SVR"
  description             = "RCC Server - Function: bc"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_rcc_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rcc_svr.name
  ip            = "bc00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rcc_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-RCC-SVR"
  display_name  = "EPG-RCC-SVR"
  bd_name       = mso_schema_template_bd.bd_rcc_svr.name
}

# ============================================================================
# Function: be - RCC-DCO | IPv6: be00::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_rcc_dco" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-RCC-DCO"
  display_name            = "BD-RCC-DCO"
  description             = "RCC DCO - Function: be"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_rcc_dco_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rcc_dco.name
  ip            = "be00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rcc_dco" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-RCC-DCO"
  display_name  = "EPG-RCC-DCO"
  bd_name       = mso_schema_template_bd.bd_rcc_dco.name
}

# ============================================================================
# Function: bf - RCC-UNIX | IPv6: bf00::1/56 | VLAN: Safe range
# ============================================================================

resource "mso_schema_template_bd" "bd_rcc_unix" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-RCC-UNIX"
  display_name            = "BD-RCC-UNIX"
  description             = "RCC UNIX - Function: bf"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_rcc_unix_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rcc_unix.name
  ip            = "bf00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_rcc_unix" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-RCC-UNIX"
  display_name  = "EPG-RCC-UNIX"
  bd_name       = mso_schema_template_bd.bd_rcc_unix.name
}

# ============================================================================
# Function: d0 - PRINT-SVR | IPv6: d000::1/56 | VLAN: 3208 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_print_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-PRINT-SVR"
  display_name            = "BD-PRINT-SVR"
  description             = "Print Server - Function: d0 - VLAN: 3208"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_print_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_print_svr.name
  ip            = "d000::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_print_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-PRINT-SVR"
  display_name  = "EPG-PRINT-SVR"
  bd_name       = mso_schema_template_bd.bd_print_svr.name
}

# ============================================================================
# Function: d1 - FILE-SVR | IPv6: d100::1/56 | VLAN: 3209 ✅
# ============================================================================

resource "mso_schema_template_bd" "bd_file_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Stretched"
  name                    = "BD-FILE-SVR"
  display_name            = "BD-FILE-SVR"
  description             = "File Server - Function: d1 - VLAN: 3209"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = true
  optimize_wan_bandwidth  = true
}

resource "mso_schema_template_bd_subnet" "bd_file_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_file_svr.name
  ip            = "d100::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_file_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-FILE-SVR"
  display_name  = "EPG-FILE-SVR"
  bd_name       = mso_schema_template_bd.bd_file_svr.name
}

# ============================================================================
# SITE ASSOCIATIONS - L2_Stretched
# ============================================================================

resource "mso_schema_site_anp" "site_anp_aedcg_stretched" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
}

resource "mso_schema_site_anp" "site_anp_aedck_stretched" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
}

# Site EPGs - AEDCG (showing all 29)
resource "mso_schema_site_anp_epg" "site_epg_nac_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_nac.name
}

resource "mso_schema_site_anp_epg" "site_epg_cfg_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_cfg_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_mecm_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_mecm.name
}

resource "mso_schema_site_anp_epg" "site_epg_lb_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_lb.name
}

resource "mso_schema_site_anp_epg" "site_epg_dns_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_dns_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_dns_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_dns.name
}

resource "mso_schema_site_anp_epg" "site_epg_dhcp_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_dhcp_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_smtp_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_smtp_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_vvoip_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_vvoip_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vvoip_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_lmr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_lmr.name
}

resource "mso_schema_site_anp_epg" "site_epg_e911_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_e911_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_acas_scanners_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_acas_scanners.name
}

resource "mso_schema_site_anp_epg" "site_epg_c2c_scanners_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_c2c_scanners.name
}

resource "mso_schema_site_anp_epg" "site_epg_ocsp_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_ocsp.name
}

resource "mso_schema_site_anp_epg" "site_epg_pki_srv_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_pki_srv.name
}

resource "mso_schema_site_anp_epg" "site_epg_ad_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_ad.name
}

resource "mso_schema_site_anp_epg" "site_epg_adfs_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_adfs.name
}

resource "mso_schema_site_anp_epg" "site_epg_d64_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_d64_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_rweb_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rweb_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_fweb_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_fweb_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_app_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_app_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_web_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_web_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_fmwr_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_fmwr_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_dco_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_dco.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_unix_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_unix.name
}

resource "mso_schema_site_anp_epg" "site_epg_print_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_print_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_file_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_file_svr.name
}

# Site EPGs - AEDCK (all 29 - identical structure for K site)
resource "mso_schema_site_anp_epg" "site_epg_nac_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_nac.name
}

resource "mso_schema_site_anp_epg" "site_epg_cfg_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_cfg_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_mecm_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_mecm.name
}

resource "mso_schema_site_anp_epg" "site_epg_lb_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_lb.name
}

resource "mso_schema_site_anp_epg" "site_epg_dns_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_dns_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_dns_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_dns.name
}

resource "mso_schema_site_anp_epg" "site_epg_dhcp_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_dhcp_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_smtp_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_smtp_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_vvoip_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
}

resource "mso_schema_site_anp_epg" "site_epg_vvoip_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_vvoip_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_lmr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_lmr.name
}

resource "mso_schema_site_anp_epg" "site_epg_e911_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_e911_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_acas_scanners_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_acas_scanners.name
}

resource "mso_schema_site_anp_epg" "site_epg_c2c_scanners_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_c2c_scanners.name
}

resource "mso_schema_site_anp_epg" "site_epg_ocsp_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_ocsp.name
}

resource "mso_schema_site_anp_epg" "site_epg_pki_srv_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_pki_srv.name
}

resource "mso_schema_site_anp_epg" "site_epg_ad_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_ad.name
}

resource "mso_schema_site_anp_epg" "site_epg_adfs_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_adfs.name
}

resource "mso_schema_site_anp_epg" "site_epg_d64_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_d64_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_rweb_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rweb_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_fweb_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_fweb_proxy.name
}

resource "mso_schema_site_anp_epg" "site_epg_app_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_app_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_web_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_web_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_fmwr_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_fmwr_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_dco_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_dco.name
}

resource "mso_schema_site_anp_epg" "site_epg_rcc_unix_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_rcc_unix.name
}

resource "mso_schema_site_anp_epg" "site_epg_print_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_print_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_file_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_file_svr.name
}

# ============================================================================
# G-SPECIFIC_ONLY TEMPLATE
# ============================================================================

resource "mso_schema_template_anp" "appprof_rcc_g_specific" {
  schema_id    = data.mso_schema.existing.id
  template     = "G-Specific_Only"
  name         = "AppProf-RCC"
  display_name = "AppProf-RCC"
}

# Function: ef - GEF-MGMT | IPv6: ef00::1/56 | VLAN: Safe range
resource "mso_schema_template_bd" "bd_gef_mgmt" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "G-Specific_Only"
  name                    = "BD-GEF-MGMT"
  display_name            = "BD-GEF-MGMT"
  description             = "GEF Management - Function: ef - G-Site Only"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = false
  optimize_wan_bandwidth  = false
  ep_move_detection_mode  = "none"
}

resource "mso_schema_template_bd_subnet" "bd_gef_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "G-Specific_Only"
  bd_name       = mso_schema_template_bd.bd_gef_mgmt.name
  ip            = "ef00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_gef_mgmt" {
  schema_id     = data.mso_schema.existing.id
  template_name = "G-Specific_Only"
  anp_name      = mso_schema_template_anp.appprof_rcc_g_specific.name
  name          = "EPG-GEF-MGMT"
  display_name  = "EPG-GEF-MGMT"
  bd_name       = mso_schema_template_bd.bd_gef_mgmt.name
}

resource "mso_schema_site_anp" "site_anp_aedcg_g_specific" {
  schema_id     = data.mso_schema.existing.id
  template_name = "G-Specific_Only"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_g_specific.name
}

resource "mso_schema_site_anp_epg" "site_epg_gef_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "G-Specific_Only"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_g_specific.name
  epg_name      = mso_schema_template_anp_epg.epg_gef_mgmt.name
}

# ============================================================================
# K-SPECIFIC_ONLY TEMPLATE
# ============================================================================

resource "mso_schema_template_anp" "appprof_rcc_k_specific" {
  schema_id    = data.mso_schema.existing.id
  template     = "K-Specific_Only"
  name         = "AppProf-RCC"
  display_name = "AppProf-RCC"
}

# Function: dd - BACKUP-SVR | IPv6: dd00::1/56 | VLAN: 3221 ✅
resource "mso_schema_template_bd" "bd_backup_svr_k" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "K-Specific_Only"
  name                    = "BD-BACKUP-SVR"
  display_name            = "BD-BACKUP-SVR"
  description             = "Backup Server - Function: dd - VLAN: 3221 - K-Site Only"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = false
  optimize_wan_bandwidth  = false
  ep_move_detection_mode  = "none"
}

resource "mso_schema_template_bd_subnet" "bd_backup_svr_k_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "K-Specific_Only"
  bd_name       = mso_schema_template_bd.bd_backup_svr_k.name
  ip            = "dd00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_backup_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "K-Specific_Only"
  anp_name      = mso_schema_template_anp.appprof_rcc_k_specific.name
  name          = "EPG-BACKUP-SVR"
  display_name  = "EPG-BACKUP-SVR"
  bd_name       = mso_schema_template_bd.bd_backup_svr_k.name
}

resource "mso_schema_site_anp" "site_anp_aedck_k_specific" {
  schema_id     = data.mso_schema.existing.id
  template_name = "K-Specific_Only"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_k_specific.name
}

resource "mso_schema_site_anp_epg" "site_epg_backup_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "K-Specific_Only"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_k_specific.name
  epg_name      = mso_schema_template_anp_epg.epg_backup_svr_k.name
}

# ============================================================================
# L2_NON-STRETCHED TEMPLATE
# ============================================================================

resource "mso_schema_template_anp" "appprof_rcc_non_stretched" {
  schema_id    = data.mso_schema.existing.id
  template     = "L2_Non-Stretched"
  name         = "AppProf-RCC"
  display_name = "AppProf-RCC"
}

# Function: db - DB-SVR | IPv6: db00::1/56 | VLAN: 3219 ✅
resource "mso_schema_template_bd" "bd_db_svr" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Non-Stretched"
  name                    = "BD-DB-SVR"
  display_name            = "BD-DB-SVR"
  description             = "Database Server - Function: db - VLAN: 3219 - Site-Local"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = false
  optimize_wan_bandwidth  = false
  ep_move_detection_mode  = "none"
}

resource "mso_schema_template_bd_subnet" "bd_db_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  bd_name       = mso_schema_template_bd.bd_db_svr.name
  ip            = "db00::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_db_svr" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_non_stretched.name
  name          = "EPG-DB-SVR"
  display_name  = "EPG-DB-SVR"
  bd_name       = mso_schema_template_bd.bd_db_svr.name
}

# Function: d9 - SYSLOG | IPv6: d900::1/56 | VLAN: 3217 ✅
resource "mso_schema_template_bd" "bd_syslog" {
  schema_id               = data.mso_schema.existing.id
  template_name           = "L2_Non-Stretched"
  name                    = "BD-SYSLOG"
  display_name            = "BD-SYSLOG"
  description             = "System Logging - Function: d9 - VLAN: 3217 - Site-Local"
  vrf_name                = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id           = data.mso_schema.existing.id
  vrf_template_name       = "UpgradeTemplate1"
  layer2_unknown_unicast  = "proxy"
  layer2_stretch          = true
  unicast_routing         = true
  intersite_bum_traffic   = false
  optimize_wan_bandwidth  = false
  ep_move_detection_mode  = "none"
}

resource "mso_schema_template_bd_subnet" "bd_syslog_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  bd_name       = mso_schema_template_bd.bd_syslog.name
  ip            = "d900::1/56"
  scope         = "public"
  shared        = false
}

resource "mso_schema_template_anp_epg" "epg_syslog" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_non_stretched.name
  name          = "EPG-SYSLOG"
  display_name  = "EPG-SYSLOG"
  bd_name       = mso_schema_template_bd.bd_syslog.name
}

# Site Associations - L2_Non-Stretched
resource "mso_schema_site_anp" "site_anp_aedcg_non_stretched" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_non_stretched.name
}

resource "mso_schema_site_anp_epg" "site_epg_db_svr_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_db_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_syslog_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_syslog.name
}

resource "mso_schema_site_anp" "site_anp_aedck_non_stretched" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_non_stretched.name
}

resource "mso_schema_site_anp_epg" "site_epg_db_svr_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_db_svr.name
}

resource "mso_schema_site_anp_epg" "site_epg_syslog_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name      = mso_schema_template_anp_epg.epg_syslog.name
}

# ============================================================================
# SITE BD CONFIGURATIONS - Host Route Enabled
# ============================================================================

# L2_Stretched BDs - AEDCG Site (29 BDs)
resource "mso_schema_site_bd" "bd_nac_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_nac.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_cfg_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_cfg_mgmt.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_mecm_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_mecm.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_lb_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_lb.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_dns_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_dns_mgmt.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_dns_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_dns.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_dhcp_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_dhcp_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_smtp_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_smtp_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_vvoip_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vvoip_mgmt.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_vvoip_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vvoip_proxy.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_lmr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_lmr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_e911_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_e911_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_acas_scanners_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_acas_scanners.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_c2c_scanners_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_c2c_scanners.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_ocsp_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_ocsp.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_pki_srv_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_pki_srv.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_ad_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_ad.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_adfs_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_adfs.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_d64_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_d64_proxy.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rweb_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rweb_proxy.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_fweb_proxy_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_fweb_proxy.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_app_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_app_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_web_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_web_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_fmwr_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_fmwr_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_dco_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_dco.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_unix_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_unix.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_print_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_print_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_file_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_file_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

# L2_Stretched BDs - AEDCK Site (29 BDs - same structure)
resource "mso_schema_site_bd" "bd_nac_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_nac.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_cfg_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_cfg_mgmt.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_mecm_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_mecm.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_lb_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_lb.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_dns_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_dns_mgmt.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_dns_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_dns.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_dhcp_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_dhcp_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_smtp_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_smtp_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_vvoip_mgmt_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vvoip_mgmt.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_vvoip_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_vvoip_proxy.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_lmr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_lmr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_e911_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_e911_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_acas_scanners_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_acas_scanners.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_c2c_scanners_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_c2c_scanners.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_ocsp_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_ocsp.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_pki_srv_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_pki_srv.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_ad_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_ad.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_adfs_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_adfs.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_d64_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_d64_proxy.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rweb_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rweb_proxy.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_fweb_proxy_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_fweb_proxy.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_app_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_app_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_web_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_web_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_fmwr_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_fmwr_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_dco_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_dco.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_rcc_unix_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_rcc_unix.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_print_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_print_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_file_svr_k" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_file_svr.name
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

# G-Specific and K-Specific BDs
resource "mso_schema_site_bd" "bd_gef_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_gef_mgmt.name
  template_name = "G-Specific_Only"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_backup_svr_k_site" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_backup_svr_k.name
  template_name = "K-Specific_Only"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

# L2_Non-Stretched BDs - Both Sites
resource "mso_schema_site_bd" "bd_db_svr_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_db_svr.name
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_db_svr_k_site" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_db_svr.name
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_syslog_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_syslog.name
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

resource "mso_schema_site_bd" "bd_syslog_k_site" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_syslog.name
  template_name = "L2_Non-Stretched"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

# ============================================================================
# PHYSICAL DOMAIN ASSOCIATIONS - All EPGs
# ============================================================================

# L2_Stretched EPGs - AEDCG (29 domains)
resource "mso_schema_site_anp_epg_domain" "epg_nac_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_nac.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_nac_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_cfg_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_cfg_mgmt.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_cfg_mgmt_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_mecm_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_mecm.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_mecm_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_lb_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_lb.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_lb_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_dns_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_dns_mgmt.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_dns_mgmt_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dns_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_dns.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_dns_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_dhcp_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_dhcp_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_dhcp_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_smtp_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_smtp_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_smtp_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vvoip_mgmt_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_proxy_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vvoip_proxy.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vvoip_proxy_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_lmr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_lmr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_lmr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_e911_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_e911_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_e911_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_acas_scanners_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_acas_scanners.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_acas_scanners_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_c2c_scanners_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_c2c_scanners.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_c2c_scanners_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_ocsp_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_ocsp.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_ocsp_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_pki_srv_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_pki_srv.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_pki_srv_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_ad_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_ad.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_ad_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_adfs_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_adfs.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_adfs_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_d64_proxy_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_d64_proxy.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_d64_proxy_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rweb_proxy_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rweb_proxy.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rweb_proxy_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_fweb_proxy_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_fweb_proxy.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_fweb_proxy_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_app_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_app_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_app_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_web_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_web_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_web_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_fmwr_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_fmwr_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_fmwr_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dco_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_dco.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_dco_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_unix_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_unix.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_unix_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_print_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_print_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_print_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_file_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_file_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_file_svr_g]
}

# L2_Stretched EPGs - AEDCK (29 domains - identical structure)
resource "mso_schema_site_anp_epg_domain" "epg_nac_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_nac.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_nac_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_cfg_mgmt_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_cfg_mgmt.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_cfg_mgmt_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_mecm_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_mecm.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_mecm_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_lb_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_lb.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_lb_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_dns_mgmt_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_dns_mgmt.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_dns_mgmt_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dns_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_dns.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_dns_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_dhcp_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_dhcp_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_dhcp_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_smtp_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_smtp_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_smtp_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_mgmt_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vvoip_mgmt_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_proxy_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_vvoip_proxy.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_vvoip_proxy_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_lmr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_lmr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_lmr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_e911_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_e911_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_e911_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_acas_scanners_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_acas_scanners.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_acas_scanners_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_c2c_scanners_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_c2c_scanners.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_c2c_scanners_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_ocsp_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_ocsp.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_ocsp_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_pki_srv_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_pki_srv.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_pki_srv_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_ad_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_ad.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_ad_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_adfs_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_adfs.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_adfs_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_d64_proxy_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_d64_proxy.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_d64_proxy_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rweb_proxy_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rweb_proxy.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rweb_proxy_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_fweb_proxy_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_fweb_proxy.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_fweb_proxy_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_app_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_app_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_app_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_web_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_web_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_web_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_fmwr_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_fmwr_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_fmwr_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dco_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_dco.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_dco_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_unix_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_rcc_unix.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_rcc_unix_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_print_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_print_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_print_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_file_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_file_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_file_svr_k]
}

# G-Specific_Only EPG Domain
resource "mso_schema_site_anp_epg_domain" "epg_gef_mgmt_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "G-Specific_Only"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_g_specific.name
  epg_name             = mso_schema_template_anp_epg.epg_gef_mgmt.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_gef_mgmt_g]
}

# K-Specific_Only EPG Domain
resource "mso_schema_site_anp_epg_domain" "epg_backup_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "K-Specific_Only"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_k_specific.name
  epg_name             = mso_schema_template_anp_epg.epg_backup_svr_k.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_backup_svr_k]
}

# L2_Non-Stretched EPG Domains - AEDCG
resource "mso_schema_site_anp_epg_domain" "epg_db_svr_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Non-Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_db_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_db_svr_g]
}

resource "mso_schema_site_anp_epg_domain" "epg_syslog_domain_g" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Non-Stretched"
  site_id              = data.mso_site.aedcg.id
  anp_name             = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_syslog.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_syslog_g]
}

# L2_Non-Stretched EPG Domains - AEDCK
resource "mso_schema_site_anp_epg_domain" "epg_db_svr_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Non-Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_db_svr.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_db_svr_k]
}

resource "mso_schema_site_anp_epg_domain" "epg_syslog_domain_k" {
  schema_id            = data.mso_schema.existing.id
  template_name        = "L2_Non-Stretched"
  site_id              = data.mso_site.aedck.id
  anp_name             = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name             = mso_schema_template_anp_epg.epg_syslog.name
  domain_type          = "physicalDomain"
  domain_name          = "PhysDom_ACI_Nexus"
  deploy_immediacy     = "immediate"
  resolution_immediacy = "immediate"
  depends_on           = [mso_schema_site_anp_epg.site_epg_syslog_k]
}
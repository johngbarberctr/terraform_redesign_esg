# Complete Terraform configuration for VRF, BDs, EPGs, and Site Associations
# Distributed across templates matching IPv4 design pattern

# Data sources for existing resources
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
# Template: UpgradeTemplate1 (VRF only - no BDs or EPGs)
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
# CONTRACT AND FILTER FOR vzAny (Single contract for single VRF)
# Template: UpgradeTemplate1
# ============================================================================

resource "mso_schema_template_contract" "contract_vrf_rcc" {
  schema_id     = data.mso_schema.existing.id
  template_name = "UpgradeTemplate1"
  contract_name = "Any_VRF-RCC"
  display_name  = "Any_VRF-RCC"
  scope         = "context"
  filter_type   = "bothWay"
  
  filter_relationship {
    filter_schema_id     = data.mso_schema.existing.id
    filter_template_name = "UpgradeTemplate1"
    filter_name          = "Any"
    filter_type          = "bothWay"
  }
}

# ============================================================================
# L2_STRETCHED TEMPLATE - 29 BDs + 29 EPGs
# Stretched across both AEDCG and AEDCK sites
# ============================================================================

# Application Profile
resource "mso_schema_template_anp" "appprof_rcc_stretched" {
  schema_id    = data.mso_schema.existing.id
  template     = "L2_Stretched"
  name         = "AppProf-RCC"
  display_name = "AppProf-RCC"
}

# Infrastructure Management (3 BDs + 3 EPGs)
resource "mso_schema_template_bd" "bd_nac" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-NAC"
  display_name           = "BD-NAC"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_nac_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_nac.name
  ip            = "fd00:10:10:15::1/64"
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

resource "mso_schema_template_bd" "bd_cfg_mgmt" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-CFG-MGMT"
  display_name           = "BD-CFG-MGMT"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_cfg_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_cfg_mgmt.name
  ip            = "fd00:10:10:69::1/64"
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

resource "mso_schema_template_bd" "bd_mecm" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-MECM"
  display_name           = "BD-MECM"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_mecm_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_mecm.name
  ip            = "fd00:10:10:ec::1/64"
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

# Network Services (5 BDs + 5 EPGs)
resource "mso_schema_template_bd" "bd_lb" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-LB"
  display_name           = "BD-LB"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_lb_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_lb.name
  ip            = "fd00:10:20:1b::1/64"
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

resource "mso_schema_template_bd" "bd_dns_mgmt" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-DNS-MGMT"
  display_name           = "BD-DNS-MGMT"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_dns_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_dns_mgmt.name
  ip            = "fd00:10:20:53::1/64"
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

resource "mso_schema_template_bd" "bd_rcc_dns" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-RCC-DNS"
  display_name           = "BD-RCC-DNS"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_rcc_dns_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rcc_dns.name
  ip            = "fd00:10:20:bd::1/64"
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

resource "mso_schema_template_bd" "bd_dhcp_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-DHCP-SVR"
  display_name           = "BD-DHCP-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_dhcp_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_dhcp_svr.name
  ip            = "fd00:10:20:d2::1/64"
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

resource "mso_schema_template_bd" "bd_smtp_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-SMTP-SVR"
  display_name           = "BD-SMTP-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_smtp_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_smtp_svr.name
  ip            = "fd00:10:20:d5::1/64"
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

# Voice and Communications (4 BDs + 4 EPGs)
resource "mso_schema_template_bd" "bd_vvoip_mgmt" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-VVOIP-MGMT"
  display_name           = "BD-VVOIP-MGMT"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_vvoip_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_vvoip_mgmt.name
  ip            = "fd00:10:30:41::1/64"
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

resource "mso_schema_template_bd" "bd_vvoip_proxy" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-VVOIP-PROXY"
  display_name           = "BD-VVOIP-PROXY"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_vvoip_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_vvoip_proxy.name
  ip            = "fd00:10:30:42::1/64"
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

resource "mso_schema_template_bd" "bd_lmr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-LMR"
  display_name           = "BD-LMR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_lmr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_lmr.name
  ip            = "fd00:10:30:cb::1/64"
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

resource "mso_schema_template_bd" "bd_e911_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-E911-SVR"
  display_name           = "BD-E911-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_e911_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_e911_svr.name
  ip            = "fd00:10:30:e9::1/64"
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

# Security Services (4 BDs + 4 EPGs)
resource "mso_schema_template_bd" "bd_acas_scanners" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-ACAS-SCANNERS"
  display_name           = "BD-ACAS-SCANNERS"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_acas_scanners_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_acas_scanners.name
  ip            = "fd00:10:40:c0::1/64"
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

resource "mso_schema_template_bd" "bd_c2c_scanners" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-C2C-SCANNERS"
  display_name           = "BD-C2C-SCANNERS"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_c2c_scanners_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_c2c_scanners.name
  ip            = "fd00:10:40:c1::1/64"
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

resource "mso_schema_template_bd" "bd_ocsp" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-OCSP"
  display_name           = "BD-OCSP"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_ocsp_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_ocsp.name
  ip            = "fd00:10:40:c5::1/64"
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

resource "mso_schema_template_bd" "bd_pki_srv" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-PKI-SRV"
  display_name           = "BD-PKI-SRV"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_pki_srv_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_pki_srv.name
  ip            = "fd00:10:40:ca::1/64"
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

# Directory and Authentication (2 BDs + 2 EPGs)
resource "mso_schema_template_bd" "bd_ad" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-AD"
  display_name           = "BD-AD"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_ad_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_ad.name
  ip            = "fd00:10:50:ad::1/64"
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

resource "mso_schema_template_bd" "bd_adfs" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-ADFS"
  display_name           = "BD-ADFS"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_adfs_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_adfs.name
  ip            = "fd00:10:50:af::1/64"
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

# Proxy Services (3 BDs + 3 EPGs)
resource "mso_schema_template_bd" "bd_d64_proxy" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-D64-PROXY"
  display_name           = "BD-D64-PROXY"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_d64_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_d64_proxy.name
  ip            = "fd00:10:60:d6::1/64"
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

resource "mso_schema_template_bd" "bd_rweb_proxy" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-RWEB-PROXY"
  display_name           = "BD-RWEB-PROXY"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_rweb_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rweb_proxy.name
  ip            = "fd00:10:60:d7::1/64"
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

resource "mso_schema_template_bd" "bd_fweb_proxy" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-FWEB-PROXY"
  display_name           = "BD-FWEB-PROXY"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_fweb_proxy_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_fweb_proxy.name
  ip            = "fd00:10:60:d8::1/64"
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

# Application and Web Servers (3 BDs + 3 EPGs)
resource "mso_schema_template_bd" "bd_app_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-APP-SVR"
  display_name           = "BD-APP-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_app_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_app_svr.name
  ip            = "fd00:10:70:e0::1/64"
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

resource "mso_schema_template_bd" "bd_web_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-WEB-SVR"
  display_name           = "BD-WEB-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_web_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_web_svr.name
  ip            = "fd00:10:70:e4::1/64"
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

resource "mso_schema_template_bd" "bd_fmwr_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-FMWR-SVR"
  display_name           = "BD-FMWR-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_fmwr_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_fmwr_svr.name
  ip            = "fd00:10:70:e3::1/64"
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

# RCC Services (3 BDs + 3 EPGs)
resource "mso_schema_template_bd" "bd_rcc_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-RCC-SVR"
  display_name           = "BD-RCC-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_rcc_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rcc_svr.name
  ip            = "fd00:10:80:bc::1/64"
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

resource "mso_schema_template_bd" "bd_rcc_dco" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-RCC-DCO"
  display_name           = "BD-RCC-DCO"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_rcc_dco_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rcc_dco.name
  ip            = "fd00:10:80:be::1/64"
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

resource "mso_schema_template_bd" "bd_rcc_unix" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-RCC-UNIX"
  display_name           = "BD-RCC-UNIX"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_rcc_unix_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_rcc_unix.name
  ip            = "fd00:10:80:bf::1/64"
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

# Storage Services (2 BDs + 2 EPGs)
resource "mso_schema_template_bd" "bd_print_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-PRINT-SVR"
  display_name           = "BD-PRINT-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_print_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_print_svr.name
  ip            = "fd00:10:90:d0::1/64"
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

resource "mso_schema_template_bd" "bd_file_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Stretched"
  name                   = "BD-FILE-SVR"
  display_name           = "BD-FILE-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = true
  optimize_wan_bandwidth = true
}

resource "mso_schema_template_bd_subnet" "bd_file_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_file_svr.name
  ip            = "fd00:10:90:d1::1/64"
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
# SITE ASSOCIATIONS - L2_Stretched (Both AEDCG and AEDCK)
# ============================================================================

# Site ANP - AEDCG
resource "mso_schema_site_anp" "site_anp_aedcg_stretched" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedcg.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
}

# Site ANP - AEDCK
resource "mso_schema_site_anp" "site_anp_aedck_stretched" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  site_id       = data.mso_site.aedck.id
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
}

# Site EPGs - AEDCG (29 EPGs)
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

# Site EPGs - AEDCK (29 EPGs)
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
# G-SPECIFIC_ONLY TEMPLATE - 1 BD + 1 EPG (AEDCG site only)
# ============================================================================

# Application Profile in G-Specific
resource "mso_schema_template_anp" "appprof_rcc_g_specific" {
  schema_id    = data.mso_schema.existing.id
  template     = "G-Specific_Only"
  name         = "AppProf-RCC"
  display_name = "AppProf-RCC"
}

resource "mso_schema_template_bd" "bd_gef_mgmt" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "G-Specific_Only"
  name                   = "BD-GEF-MGMT"
  display_name           = "BD-GEF-MGMT"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = false
  optimize_wan_bandwidth = false
  ep_move_detection_mode = "none"
}

resource "mso_schema_template_bd_subnet" "bd_gef_mgmt_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "G-Specific_Only"
  bd_name       = mso_schema_template_bd.bd_gef_mgmt.name
  ip            = "fd00:10:10:ef::1/64"
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

# Site Association - AEDCG only
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
# K-SPECIFIC_ONLY TEMPLATE - 1 BD + 1 EPG (AEDCK site only)
# ============================================================================

# Application Profile in K-Specific
resource "mso_schema_template_anp" "appprof_rcc_k_specific" {
  schema_id    = data.mso_schema.existing.id
  template     = "K-Specific_Only"
  name         = "AppProf-RCC"
  display_name = "AppProf-RCC"
}

resource "mso_schema_template_bd" "bd_backup_svr_k" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "K-Specific_Only"
  name                   = "BD-BACKUP-SVR"
  display_name           = "BD-BACKUP-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = false
  optimize_wan_bandwidth = false
  ep_move_detection_mode = "none"
}

resource "mso_schema_template_bd_subnet" "bd_backup_svr_k_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "K-Specific_Only"
  bd_name       = mso_schema_template_bd.bd_backup_svr_k.name
  ip            = "fd00:10:90:dd::1/64"
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

# Site Association - AEDCK only
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
# L2_NON-STRETCHED TEMPLATE - 2 BDs + 2 EPGs (Site-local)
# ============================================================================

# Application Profile in L2_Non-Stretched
resource "mso_schema_template_anp" "appprof_rcc_non_stretched" {
  schema_id    = data.mso_schema.existing.id
  template     = "L2_Non-Stretched"
  name         = "AppProf-RCC"
  display_name = "AppProf-RCC"
}

# Database Server (site-local for data locality)
resource "mso_schema_template_bd" "bd_db_svr" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Non-Stretched"
  name                   = "BD-DB-SVR"
  display_name           = "BD-DB-SVR"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = false
  optimize_wan_bandwidth = false
  ep_move_detection_mode = "none"
}

resource "mso_schema_template_bd_subnet" "bd_db_svr_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  bd_name       = mso_schema_template_bd.bd_db_svr.name
  ip            = "fd00:10:a0:db::1/64"
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

# Syslog (site-local logging)
resource "mso_schema_template_bd" "bd_syslog" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "L2_Non-Stretched"
  name                   = "BD-SYSLOG"
  display_name           = "BD-SYSLOG"
  vrf_name               = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id          = data.mso_schema.existing.id
  vrf_template_name      = "UpgradeTemplate1"
  layer2_unknown_unicast = "proxy"
  layer2_stretch         = true
  unicast_routing        = true
  intersite_bum_traffic  = false
  optimize_wan_bandwidth = false
  ep_move_detection_mode = "none"
}

resource "mso_schema_template_bd_subnet" "bd_syslog_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Non-Stretched"
  bd_name       = mso_schema_template_bd.bd_syslog.name
  ip            = "fd00:10:a0:d9::1/64"
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

# Site Associations - Both sites (each gets local instance)
# AEDCG
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

# AEDCK
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
# Required for proper routing behavior at site level
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

# L2_Stretched BDs - AEDCK Site (29 BDs)
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

# G-Specific_Only BD - AEDCG Site (1 BD)
resource "mso_schema_site_bd" "bd_gef_mgmt_g" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_gef_mgmt.name
  template_name = "G-Specific_Only"
  site_id       = data.mso_site.aedcg.id
  host_route    = true
}

# K-Specific_Only BD - AEDCK Site (1 BD)
resource "mso_schema_site_bd" "bd_backup_svr_k_site" {
  schema_id     = data.mso_schema.existing.id
  bd_name       = mso_schema_template_bd.bd_backup_svr_k.name
  template_name = "K-Specific_Only"
  site_id       = data.mso_site.aedck.id
  host_route    = true
}

# L2_Non-Stretched BDs - Both Sites (2 BDs × 2 sites = 4 resources)
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
# PHYSICAL DOMAIN ASSOCIATIONS
# Associates EPGs with PhysDom_ACI_Nexus for static port binding capability
# ============================================================================

# L2_Stretched EPGs - AEDCG (29 EPGs)
resource "mso_schema_site_anp_epg_domain" "epg_nac_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_nac.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_nac_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_cfg_mgmt_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_cfg_mgmt.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_cfg_mgmt_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_mecm_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_mecm.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_mecm_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_lb_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_lb.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_lb_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_dns_mgmt_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_dns_mgmt.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_dns_mgmt_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dns_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rcc_dns.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rcc_dns_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_dhcp_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_dhcp_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_dhcp_svr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_smtp_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_smtp_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_smtp_svr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_mgmt_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_vvoip_mgmt_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_proxy_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_vvoip_proxy.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_vvoip_proxy_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_lmr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_lmr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_lmr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_e911_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_e911_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_e911_svr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_acas_scanners_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_acas_scanners.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_acas_scanners_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_c2c_scanners_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_c2c_scanners.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_c2c_scanners_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_ocsp_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_ocsp.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_ocsp_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_pki_srv_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_pki_srv.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_pki_srv_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_ad_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_ad.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_ad_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_adfs_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_adfs.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_adfs_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_d64_proxy_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_d64_proxy.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_d64_proxy_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rweb_proxy_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rweb_proxy.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rweb_proxy_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_fweb_proxy_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_fweb_proxy.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_fweb_proxy_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_app_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_app_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_app_svr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_web_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_web_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_web_svr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_fmwr_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_fmwr_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_fmwr_svr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rcc_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rcc_svr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dco_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rcc_dco.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rcc_dco_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_unix_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rcc_unix.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rcc_unix_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_print_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_print_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_print_svr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_file_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_file_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_file_svr_g
  ]
}

# L2_Stretched EPGs - AEDCK (29 EPGs)
resource "mso_schema_site_anp_epg_domain" "epg_nac_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_nac.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_nac_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_cfg_mgmt_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_cfg_mgmt.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_cfg_mgmt_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_mecm_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_mecm.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_mecm_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_lb_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_lb.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_lb_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_dns_mgmt_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_dns_mgmt.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_dns_mgmt_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dns_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rcc_dns.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rcc_dns_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_dhcp_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_dhcp_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_dhcp_svr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_smtp_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_smtp_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_smtp_svr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_mgmt_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_vvoip_mgmt.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_vvoip_mgmt_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_vvoip_proxy_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_vvoip_proxy.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_vvoip_proxy_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_lmr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_lmr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_lmr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_e911_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_e911_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_e911_svr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_acas_scanners_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_acas_scanners.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_acas_scanners_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_c2c_scanners_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_c2c_scanners.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_c2c_scanners_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_ocsp_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_ocsp.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_ocsp_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_pki_srv_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_pki_srv.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_pki_srv_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_ad_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_ad.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_ad_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_adfs_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_adfs.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_adfs_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_d64_proxy_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_d64_proxy.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_d64_proxy_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rweb_proxy_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rweb_proxy.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rweb_proxy_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_fweb_proxy_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_fweb_proxy.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_fweb_proxy_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_app_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_app_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_app_svr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_web_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_web_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_web_svr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_fmwr_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_fmwr_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_fmwr_svr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rcc_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rcc_svr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_dco_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rcc_dco.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rcc_dco_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_rcc_unix_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_rcc_unix.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_rcc_unix_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_print_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_print_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_print_svr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_file_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_file_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_file_svr_k
  ]
}

# G-Specific_Only EPG - AEDCG
resource "mso_schema_site_anp_epg_domain" "epg_gef_mgmt_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "G-Specific_Only"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_g_specific.name
  epg_name          = mso_schema_template_anp_epg.epg_gef_mgmt.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_gef_mgmt_g
  ]
}

# K-Specific_Only EPG - AEDCK
resource "mso_schema_site_anp_epg_domain" "epg_backup_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "K-Specific_Only"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_k_specific.name
  epg_name          = mso_schema_template_anp_epg.epg_backup_svr_k.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_backup_svr_k
  ]
}

# L2_Non-Stretched EPGs - AEDCG
resource "mso_schema_site_anp_epg_domain" "epg_db_svr_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Non-Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_db_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_db_svr_g
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_syslog_domain_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Non-Stretched"
  site_id           = data.mso_site.aedcg.id
  anp_name          = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_syslog.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_syslog_g
  ]
}

# L2_Non-Stretched EPGs - AEDCK
resource "mso_schema_site_anp_epg_domain" "epg_db_svr_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Non-Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_db_svr.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_db_svr_k
  ]
}

resource "mso_schema_site_anp_epg_domain" "epg_syslog_domain_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Non-Stretched"
  site_id           = data.mso_site.aedck.id
  anp_name          = mso_schema_template_anp.appprof_rcc_non_stretched.name
  epg_name          = mso_schema_template_anp_epg.epg_syslog.name
  domain_type       = "physicalDomain"
  domain_name       = "PhysDom_ACI_Nexus"
  deploy_immediacy  = "immediate"
  resolution_immediacy = "immediate"
  
  depends_on = [
    mso_schema_site_anp_epg.site_epg_syslog_k
  ]
}
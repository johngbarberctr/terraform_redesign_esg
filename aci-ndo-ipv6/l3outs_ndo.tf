# ============================================================================
# AFRICOM L3OUT CONFIGURATION - NDO
# ============================================================================
# Site-specific L3Outs serving all BDs in AFR-PROD-V6
#
# Architecture (NDO-compliant):
#   - L3Out-Kelley-V2 in Kelley_Unique template (Site G)
#   - L3Out-Del-Din-V2 in Del_Din_Unique template (Site K)
#   - ExtEPG-Kelley-V2 in Kelley_Unique (Site G External EPG)
#   - ExtEPG-Del-Din-V2 in Del_Din_Unique (Site K External EPG)
#
# NOTE: NDO requires unique L3Out names across templates when deployed.
# Site-local External EPGs reference their respective L3Outs.
# ============================================================================

# ============================================================================
# DATA SOURCES & VRF - Defined in bds_epgs.tf
# ============================================================================
# The following resources are defined in bds_epgs.tf and shared:
#   - data.mso_schema.existing
#   - data.mso_site.site1
#   - data.mso_site.site2
#   - data.mso_tenant.eur
#   - mso_schema_template_vrf.vrf_rcc
# ============================================================================

# ============================================================================
# L3OUT DEFINITIONS - Unique names per site
# ============================================================================

resource "mso_schema_template_l3out" "l3out_rcc_e_g" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "Kelley_Unique"
  l3out_name        = "L3Out-Kelley-V2"
  display_name      = "L3Out-Kelley-V2"
  description       = "L3Out for Site G (Grafenwoehr) - All BDs"
  vrf_name          = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id     = data.mso_schema.existing.id
  vrf_template_name = var.vrf_template_name
}

resource "mso_schema_template_l3out" "l3out_rcc_e_k" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "Del_Din_Unique"
  l3out_name        = "L3Out-Del-Din-V2"
  display_name      = "L3Out-Del-Din-V2"
  description       = "L3Out for Site K (Kaiserslautern) - All BDs"
  vrf_name          = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id     = data.mso_schema.existing.id
  vrf_template_name = var.vrf_template_name
}

# ============================================================================
# EXTERNAL EPG - Site G (Kelley_Unique)
# ============================================================================

resource "mso_schema_template_external_epg" "ext_epg_rcc_e_g" {
  schema_id           = data.mso_schema.existing.id
  template_name       = "Kelley_Unique"
  external_epg_name   = "ExtEPG-Kelley-V2"
  display_name        = "ExtEPG-Kelley-V2"
  external_epg_type   = "on-premise"
  vrf_name            = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id       = data.mso_schema.existing.id
  vrf_template_name   = var.vrf_template_name
  l3out_name          = "L3Out-Kelley-V2"
  l3out_schema_id     = data.mso_schema.existing.id
  l3out_template_name = "Kelley_Unique"

  depends_on = [mso_schema_template_l3out.l3out_rcc_e_g]
}

resource "mso_schema_template_external_epg_subnet" "ext_epg_rcc_e_g_subnet" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "Kelley_Unique"
  external_epg_name = mso_schema_template_external_epg.ext_epg_rcc_e_g.external_epg_name
  ip                = "::/0"
  scope             = ["import-security"]
  aggregate         = []

  depends_on = [mso_schema_template_external_epg.ext_epg_rcc_e_g]
}

resource "mso_schema_template_external_epg_contract" "ext_epg_rcc_e_g_consumer" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "Kelley_Unique"
  external_epg_name      = mso_schema_template_external_epg.ext_epg_rcc_e_g.external_epg_name
  relationship_type      = "consumer"
  contract_name          = mso_schema_template_contract.contract_vrf_rcc.contract_name
  contract_schema_id     = data.mso_schema.existing.id
  contract_template_name = var.vrf_template_name

  depends_on = [mso_schema_template_external_epg.ext_epg_rcc_e_g]
}

resource "mso_schema_template_external_epg_contract" "ext_epg_rcc_e_g_provider" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "Kelley_Unique"
  external_epg_name      = mso_schema_template_external_epg.ext_epg_rcc_e_g.external_epg_name
  relationship_type      = "provider"
  contract_name          = mso_schema_template_contract.contract_vrf_rcc.contract_name
  contract_schema_id     = data.mso_schema.existing.id
  contract_template_name = var.vrf_template_name

  depends_on = [mso_schema_template_external_epg.ext_epg_rcc_e_g]
}

# ============================================================================
# EXTERNAL EPG - Site K (Del_Din_Unique)
# ============================================================================

resource "mso_schema_template_external_epg" "ext_epg_rcc_e_k" {
  schema_id           = data.mso_schema.existing.id
  template_name       = "Del_Din_Unique"
  external_epg_name   = "ExtEPG-Del-Din-V2"
  display_name        = "ExtEPG-Del-Din-V2"
  external_epg_type   = "on-premise"
  vrf_name            = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id       = data.mso_schema.existing.id
  vrf_template_name   = var.vrf_template_name
  l3out_name          = "L3Out-Del-Din-V2"
  l3out_schema_id     = data.mso_schema.existing.id
  l3out_template_name = "Del_Din_Unique"

  depends_on = [mso_schema_template_l3out.l3out_rcc_e_k]
}

resource "mso_schema_template_external_epg_subnet" "ext_epg_rcc_e_k_subnet" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "Del_Din_Unique"
  external_epg_name = mso_schema_template_external_epg.ext_epg_rcc_e_k.external_epg_name
  ip                = "::/0"
  scope             = ["import-security"]
  aggregate         = []

  depends_on = [mso_schema_template_external_epg.ext_epg_rcc_e_k]
}

resource "mso_schema_template_external_epg_contract" "ext_epg_rcc_e_k_consumer" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "Del_Din_Unique"
  external_epg_name      = mso_schema_template_external_epg.ext_epg_rcc_e_k.external_epg_name
  relationship_type      = "consumer"
  contract_name          = mso_schema_template_contract.contract_vrf_rcc.contract_name
  contract_schema_id     = data.mso_schema.existing.id
  contract_template_name = var.vrf_template_name

  depends_on = [mso_schema_template_external_epg.ext_epg_rcc_e_k]
}

resource "mso_schema_template_external_epg_contract" "ext_epg_rcc_e_k_provider" {
  schema_id              = data.mso_schema.existing.id
  template_name          = "Del_Din_Unique"
  external_epg_name      = mso_schema_template_external_epg.ext_epg_rcc_e_k.external_epg_name
  relationship_type      = "provider"
  contract_name          = mso_schema_template_contract.contract_vrf_rcc.contract_name
  contract_schema_id     = data.mso_schema.existing.id
  contract_template_name = var.vrf_template_name

  depends_on = [mso_schema_template_external_epg.ext_epg_rcc_e_k]
}

# ============================================================================

# BD-L3OUT ASSOCIATIONS - Stretched_Services BDs (Both Sites)
# ============================================================================

# --- BD-NAC ---
resource "mso_schema_site_bd_l3out" "bd_nac_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_nac_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_nac_g, mso_schema_template_l3out.l3out_rcc_e_g, mso_schema_template_external_epg.ext_epg_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_nac_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_nac_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_nac_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-CFG-MGMT ---
resource "mso_schema_site_bd_l3out" "bd_cfg_mgmt_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_cfg_mgmt_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_cfg_mgmt_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_cfg_mgmt_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_cfg_mgmt_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_cfg_mgmt_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-MECM ---
resource "mso_schema_site_bd_l3out" "bd_mecm_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_mecm_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_mecm_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_mecm_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_mecm_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_mecm_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-LB ---
resource "mso_schema_site_bd_l3out" "bd_lb_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_lb_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_lb_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_lb_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_lb_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_lb_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-DNS-MGMT ---
resource "mso_schema_site_bd_l3out" "bd_dns_mgmt_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_dns_mgmt_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_dns_mgmt_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_dns_mgmt_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_dns_mgmt_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_dns_mgmt_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-AFRICOM-DNS ---
resource "mso_schema_site_bd_l3out" "bd_rcc_dns_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_rcc_dns_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_rcc_dns_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_rcc_dns_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_rcc_dns_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_rcc_dns_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-DHCP-SVR ---
resource "mso_schema_site_bd_l3out" "bd_dhcp_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_dhcp_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_dhcp_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_dhcp_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_dhcp_svr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_dhcp_svr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-SMTP-SVR ---
resource "mso_schema_site_bd_l3out" "bd_smtp_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_smtp_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_smtp_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_smtp_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_smtp_svr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_smtp_svr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-VVOIP-MGMT ---
resource "mso_schema_site_bd_l3out" "bd_vvoip_mgmt_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_vvoip_mgmt_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_vvoip_mgmt_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_vvoip_mgmt_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_vvoip_mgmt_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_vvoip_mgmt_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-VVOIP-PROXY ---
resource "mso_schema_site_bd_l3out" "bd_vvoip_proxy_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_vvoip_proxy_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_vvoip_proxy_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_vvoip_proxy_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_vvoip_proxy_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_vvoip_proxy_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-LMR ---
resource "mso_schema_site_bd_l3out" "bd_lmr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_lmr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_lmr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_lmr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_lmr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_lmr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-E911-SVR ---
resource "mso_schema_site_bd_l3out" "bd_e911_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_e911_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_e911_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_e911_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_e911_svr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_e911_svr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-ACAS-SCANNERS ---
resource "mso_schema_site_bd_l3out" "bd_acas_scanners_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_acas_scanners_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_acas_scanners_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_acas_scanners_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_acas_scanners_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_acas_scanners_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-C2C-SCANNERS ---
resource "mso_schema_site_bd_l3out" "bd_c2c_scanners_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_c2c_scanners_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_c2c_scanners_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_c2c_scanners_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_c2c_scanners_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_c2c_scanners_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-OCSP ---
resource "mso_schema_site_bd_l3out" "bd_ocsp_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_ocsp_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_ocsp_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_ocsp_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_ocsp_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_ocsp_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-PKI-SRV ---
resource "mso_schema_site_bd_l3out" "bd_pki_srv_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_pki_srv_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_pki_srv_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_pki_srv_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_pki_srv_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_pki_srv_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-AD ---
resource "mso_schema_site_bd_l3out" "bd_ad_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_ad_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_ad_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_ad_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_ad_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_ad_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-ADFS ---
resource "mso_schema_site_bd_l3out" "bd_adfs_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_adfs_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_adfs_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_adfs_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_adfs_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_adfs_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-D64-PROXY ---
resource "mso_schema_site_bd_l3out" "bd_d64_proxy_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_d64_proxy_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_d64_proxy_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_d64_proxy_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_d64_proxy_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_d64_proxy_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-RWEB-PROXY ---
resource "mso_schema_site_bd_l3out" "bd_rweb_proxy_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_rweb_proxy_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_rweb_proxy_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_rweb_proxy_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_rweb_proxy_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_rweb_proxy_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-FWEB-PROXY ---
resource "mso_schema_site_bd_l3out" "bd_fweb_proxy_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_fweb_proxy_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_fweb_proxy_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_fweb_proxy_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_fweb_proxy_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_fweb_proxy_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-APP-SVR ---
resource "mso_schema_site_bd_l3out" "bd_app_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_app_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_app_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_app_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_app_svr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_app_svr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-WEB-SVR ---
resource "mso_schema_site_bd_l3out" "bd_web_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_web_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_web_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_web_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_web_svr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_web_svr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-FMWR-SVR ---
resource "mso_schema_site_bd_l3out" "bd_fmwr_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_fmwr_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_fmwr_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_fmwr_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_fmwr_svr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_fmwr_svr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-AFRICOM-SVR ---
resource "mso_schema_site_bd_l3out" "bd_rcc_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_rcc_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_rcc_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_rcc_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_rcc_svr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_rcc_svr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-AFRICOM-DCO ---
resource "mso_schema_site_bd_l3out" "bd_rcc_dco_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_rcc_dco_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_rcc_dco_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_rcc_dco_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_rcc_dco_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_rcc_dco_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-AFRICOM-UNIX ---
resource "mso_schema_site_bd_l3out" "bd_rcc_unix_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_rcc_unix_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_rcc_unix_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_rcc_unix_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_rcc_unix_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_rcc_unix_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-PRINT-SVR ---
resource "mso_schema_site_bd_l3out" "bd_print_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_print_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_print_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_print_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_print_svr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_print_svr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-FILE-SVR ---
resource "mso_schema_site_bd_l3out" "bd_file_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_file_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_file_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_file_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_file_svr_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_file_svr_k, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-NMS ---

resource "mso_schema_site_bd_l3out" "bd_nms_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_nms_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_nms_g, mso_schema_template_l3out.l3out_rcc_e_g]
}


resource "mso_schema_site_bd_l3out" "bd_nms_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_nms_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_nms_k, mso_schema_template_l3out.l3out_rcc_e_k]
}


# --- BD-VHOST-MGMT ---

resource "mso_schema_site_bd_l3out" "bd_vhost_mgmt_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_vhost_mgmt_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_vhost_mgmt_g, mso_schema_template_l3out.l3out_rcc_e_g]
}


resource "mso_schema_site_bd_l3out" "bd_vhost_mgmt_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_vhost_mgmt_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_vhost_mgmt_k, mso_schema_template_l3out.l3out_rcc_e_k]
}


# --- BD-ADM-DCO ---

resource "mso_schema_site_bd_l3out" "bd_adm_dco_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_adm_dco_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_adm_dco_g, mso_schema_template_l3out.l3out_rcc_e_g]
}


resource "mso_schema_site_bd_l3out" "bd_adm_dco_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_adm_dco_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_adm_dco_k, mso_schema_template_l3out.l3out_rcc_e_k]
}


# --- BD-SYSMAN ---

resource "mso_schema_site_bd_l3out" "bd_sysman_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_sysman_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_sysman_g, mso_schema_template_l3out.l3out_rcc_e_g]
}


resource "mso_schema_site_bd_l3out" "bd_sysman_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_sysman_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_sysman_k, mso_schema_template_l3out.l3out_rcc_e_k]
}


# --- BD-ACAS-MGMT ---

resource "mso_schema_site_bd_l3out" "bd_acas_mgmt_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_acas_mgmt_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_acas_mgmt_g, mso_schema_template_l3out.l3out_rcc_e_g]
}


resource "mso_schema_site_bd_l3out" "bd_acas_mgmt_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_acas_mgmt_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_acas_mgmt_k, mso_schema_template_l3out.l3out_rcc_e_k]
}


# --- BD-PATCH ---

resource "mso_schema_site_bd_l3out" "bd_patch_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_patch_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_patch_g, mso_schema_template_l3out.l3out_rcc_e_g]
}


resource "mso_schema_site_bd_l3out" "bd_patch_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_patch_k.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_patch_k, mso_schema_template_l3out.l3out_rcc_e_k]
}


# ============================================================================
# BD-L3OUT ASSOCIATIONS - Site-Specific BDs
# ============================================================================

# --- BD-GEF-MGMT (Kelley_Unique - Site G only) ---
resource "mso_schema_site_bd_l3out" "bd_gef_mgmt_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Kelley_Unique"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_gef_mgmt_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_gef_mgmt_g, mso_schema_template_l3out.l3out_rcc_e_g]
}

# --- BD-BACKUP-SVR (Del_Din_Unique - Site K only) ---
resource "mso_schema_site_bd_l3out" "bd_backup_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Del_Din_Unique"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_backup_svr_k_site.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_backup_svr_k_site, mso_schema_template_l3out.l3out_rcc_e_k]
}

# ============================================================================
# BD-L3OUT ASSOCIATIONS - Stretched_Services (was L2_Non-Stretched) BDs (Both Sites)
# ============================================================================

# --- BD-DB-SVR ---
resource "mso_schema_site_bd_l3out" "bd_db_svr_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_db_svr_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_db_svr_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_db_svr_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_db_svr_k_site.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_db_svr_k_site, mso_schema_template_l3out.l3out_rcc_e_k]
}

# --- BD-SYSLOG ---
resource "mso_schema_site_bd_l3out" "bd_syslog_l3out_g" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site1.id
  bd_name       = mso_schema_site_bd.bd_syslog_g.bd_name
  l3out_name    = "L3Out-Kelley-V2"
  depends_on    = [mso_schema_site_bd.bd_syslog_g, mso_schema_template_l3out.l3out_rcc_e_g]
}
resource "mso_schema_site_bd_l3out" "bd_syslog_l3out_k" {
  schema_id     = data.mso_schema.existing.id
  template_name = "Stretched_Services"
  site_id       = data.mso_site.site2.id
  bd_name       = mso_schema_site_bd.bd_syslog_k_site.bd_name
  l3out_name    = "L3Out-Del-Din-V2"
  depends_on    = [mso_schema_site_bd.bd_syslog_k_site, mso_schema_template_l3out.l3out_rcc_e_k]
}

# NDO (Nexus Dashboard Orchestrator) provider. One MSO endpoint manages both
# Kelley and Del-Din -- no aliases needed (compare to apic-vmware/providers.tf,
# which keeps two aci providers because each APIC is its own control plane).

provider "mso" {
  username = var.ndo_username
  password = var.ndo_password
  url      = var.ndo_url
  domain   = var.ndo_domain
  platform = var.ndo_platform
  insecure = var.ndo_insecure
}

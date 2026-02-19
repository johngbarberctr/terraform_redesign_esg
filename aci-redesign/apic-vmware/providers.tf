provider "aci" {
  url      = var.apic_url
  username = var.apic_username
  password = var.apic_password
  insecure = var.apic_insecure
}

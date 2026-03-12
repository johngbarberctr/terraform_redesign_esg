terraform {
  backend "http" {}

  required_providers {
    mso = {
      source  = "CiscoDevNet/mso"
      version = "~> 1.5.0"
    }
    aci = {
      source  = "CiscoDevNet/aci"
      version = ">= 2.0.0"
    }
  }
}

provider "mso" {
  username = var.ndo_username
  password = var.ndo_password
  url      = var.ndo_url
  domain   = var.mso_domain
  platform = var.mso_platform
  insecure = true
}
terraform {
  required_providers {
    mso = {
      source  = "CiscoDevNet/mso"
      version = ">= 1.5.2"
    }
  }
}

provider "mso" {
  username = var.ndo_username
  password = var.ndo_password
  url      = var.ndo_url
  insecure = true
}
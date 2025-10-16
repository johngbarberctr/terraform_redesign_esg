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

variable "ndo_username" {}
variable "ndo_password" {}
variable "ndo_url" {}

data "mso_site" "test_aedcg" {
  name = "AEDCG"
}

data "mso_site" "test_aedck" {
  name = "AEDCK"
}

output "site_ids" {
  value = {
    aedcg = data.mso_site.test_aedcg.id
    aedck = data.mso_site.test_aedck.id
  }
}

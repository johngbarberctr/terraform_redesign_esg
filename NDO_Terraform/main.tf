terraform {
  required_providers {
    mso = {
      source  = "CiscoDevNet/mso"
      version = ">= 1.5.2"
    }
  }
  required_version = ">= 1.3"
}

provider "mso" {
  username = var.ndo_username
  password = var.ndo_password
  url      = var.ndo_url
  insecure = true
}

module "ndo" {
  source  = "netascode/nac-ndo/mso"
  version = "1.1.0"  
   
   # Directory containing all YAML files
  yaml_directories = ["data"]

  # Or specify individual files to process in order
  # Uncomment the files you want to deploy
  yaml_files = [
    "data/excluded/1-base-build.nac1.yaml",
    #"data/excluded/2-add-single-esg-for-all-epgs.nac.yaml",
    # "data/excluded/3-add-app-centric-migration.nac.yaml",
    # "data/4-add-tighter-contracts-ndo.yaml"
  ]

  # Control which resources to manage
  manage_schemas    = true
  manage_sites      = false
  manage_tenants    = false
  #manage_system     = true
}
# provider.tf or main.tf

terraform {
  required_providers {
    mso = {
      source  = "CiscoDevNet/mso"
      version = "~> 1.1.0"  # Use appropriate version
    }
  }
}

provider "mso" {
  username = "admin"
  password = "IRanthehoodtocoast2021@"
  url      = "https://198.18.1.12"  # NDO/MSO IP address
  insecure = true  # Set to false if using valid certificates
  domain   = "local"  # or your authentication domain
}
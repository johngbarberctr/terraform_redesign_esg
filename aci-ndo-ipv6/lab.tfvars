# Lab environment configuration knobs only.
#
# Credentials and the NDO URL belong in terraform.tfvars (auto-loaded,
# gitignored, holds the active environment's secrets) -- NOT in this file.
# Putting credentials here would override terraform.tfvars whenever you pass
# -var-file=lab.tfvars and silently break the plan with errors like
#   Error: Post "/login": unsupported protocol scheme ""
# whenever the credentials drift between the two files.
#
# Usage:
#   terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 -out=plan.tfplan
#
# Provider/template values that are unique to the lab fabric:

vrf_template_name = "VRF_Template"  # production uses "UpgradeTemplate1"
mso_domain        = "local"          # NDO local domain for the admin user
mso_platform      = "nd"             # MSO provider platform = Nexus Dashboard

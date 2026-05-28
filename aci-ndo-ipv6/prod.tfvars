# Production environment configuration knobs only.
#
# Credentials and the NDO URL belong in terraform.tfvars (auto-loaded,
# gitignored, holds the active environment's secrets) -- NOT in this file.
# See lab.tfvars for the rationale.
#
# Usage (production NDO from CLI):
#   terraform plan -var-file=prod.tfvars -refresh=false -parallelism=3 -out=plan.tfplan
#
# Provider/template values that are unique to the production fabric. The MSO
# provider's domain and platform fall through to their variable defaults
# (null) for production -- explicit "local"/"nd" are lab-specific.

vrf_template_name = "UpgradeTemplate1"  # lab uses "VRF_Template"

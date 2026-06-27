# apic-vmware Makefile
#
# Thin wrapper around terraform that guarantees the VMware VMM-domain YAML
# is rendered BEFORE terraform reads it (one rendered file per fabric).
# See README sections 4-5 for why the render step is out-of-band instead of
# a local_file resource.
#
# Usage:
#   make init                      -- terraform init (one-time / after module bumps)
#   make fmt                       -- terraform fmt -check -recursive
#   make validate                  -- render BOTH fabrics + init (no backend) + validate
#   make plan                      -- render BOTH fabrics + plan -out=plan.tfplan
#                                     (uses lab.tfvars by default)
#   make plan TFVARS_FILE=prod.tfvars  -- same but against prod
#   make apply                     -- terraform apply plan.tfplan (BOTH fabrics)
#   make apply-kelley              -- apply only Kelley  (-target=module.aci_kelley
#                                                         + aci_rest_managed.mcp_inst_pol_kelley)
#   make apply-deldin              -- apply only Del-Din
#   make destroy                   -- destroy BOTH fabrics
#   make destroy-kelley            -- destroy only Kelley
#   make destroy-deldin            -- destroy only Del-Din
#   make render                    -- render BOTH fabrics' VMM YAML
#   make render-kelley             -- render only Kelley VMM YAML
#   make render-deldin             -- render only Del-Din VMM YAML
#   make auth-check                -- POST aaaLogin to BOTH fabrics
#   make auth-check FABRIC=kelley  -- probe Kelley only
#   make auth-check FABRIC=deldin  -- probe Del-Din only
#   make clean                     -- remove rendered YAMLs and tfplan files
#
# Required env vars (the GitLab CI pipeline uses the same names under the hood):
#   TF_VAR_kelley_apic_password    -- Kelley admin password
#   TF_VAR_deldin_apic_password    -- Del-Din admin password
#   TF_VAR_kelley_mcp_key          -- Kelley MCP key (>=8 char, mixed classes)
#   TF_VAR_deldin_mcp_key          -- Del-Din MCP key (>=8 char, mixed classes)
#   TF_VAR_vcenter_hostname_ip     -- shared vCenter (both fabrics today)
#   TF_VAR_vcenter_datacenter
#   TF_VAR_vcenter_username
#   TF_VAR_vcenter_password
#   TF_VAR_vcenter_dvs_version

.PHONY: init fmt validate plan apply apply-kelley apply-deldin \
        destroy destroy-kelley destroy-deldin \
        render render-kelley render-deldin \
        clean check-env check-env-kelley check-env-deldin auth-check

RENDER         := ./scripts/render-vmm-yaml.sh
AUTH_CHECK     := ./scripts/auth-check.sh
RENDERED_Kelley := ./data/nac-aci-kelley-rendered/vmm-domain.nac.yaml
RENDERED_DelDin := ./data/nac-aci-deldin-rendered/vmm-domain.nac.yaml
PLAN_FILE      := plan.tfplan
DESTROY_FILE   := destroy.tfplan
TFVARS_FILE    ?= lab.tfvars

# Module groupings for -target dispatch on partial-fabric apply/destroy.
TARGETS_Kelley := -target=module.aci_kelley -target=aci_rest_managed.mcp_inst_pol_kelley
TARGETS_DelDin := -target=module.aci_deldin -target=aci_rest_managed.mcp_inst_pol_deldin

# Shared (vCenter) env vars -- needed by both fabrics' render step.
SHARED_ENV := TF_VAR_vcenter_hostname_ip \
              TF_VAR_vcenter_datacenter \
              TF_VAR_vcenter_username \
              TF_VAR_vcenter_password \
              TF_VAR_vcenter_dvs_version

# Per-fabric env vars consumed by Terraform.
Kelley_ENV := TF_VAR_kelley_apic_password TF_VAR_kelley_mcp_key
DelDin_ENV := TF_VAR_deldin_apic_password TF_VAR_deldin_mcp_key

# Pass FABRIC=kelley or FABRIC=deldin to scope auth-check; empty == both.
FABRIC ?=

check-env-kelley:
	@missing=""; \
	for v in $(SHARED_ENV) $(Kelley_ENV); do \
	    eval val=\$$$$v; \
	    if [ -z "$$val" ]; then missing="$$missing $$v"; fi; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "Missing Kelley env var(s):$$missing" >&2; \
	    echo "Export them before running make. See README section 4." >&2; \
	    exit 1; \
	fi

check-env-deldin:
	@missing=""; \
	for v in $(SHARED_ENV) $(DelDin_ENV); do \
	    eval val=\$$$$v; \
	    if [ -z "$$val" ]; then missing="$$missing $$v"; fi; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "Missing Del-Din env var(s):$$missing" >&2; \
	    echo "Export them before running make. See README section 4." >&2; \
	    exit 1; \
	fi

check-env: check-env-kelley check-env-deldin

render-kelley: check-env-kelley
	@$(RENDER) kelley

render-deldin: check-env-deldin
	@$(RENDER) deldin

render: render-kelley render-deldin

init:
	terraform init -input=false

fmt:
	terraform fmt -check -recursive

validate: render
	terraform init -backend=false -input=false
	terraform validate -var-file=$(TFVARS_FILE)

plan: render
	terraform plan -out=$(PLAN_FILE) -input=false -var-file=$(TFVARS_FILE)

apply: render
	terraform apply -input=false $(PLAN_FILE)

# Partial applies use -target so you can promote Kelley to production while
# Del-Din is still being validated, or vice versa. No -auto-approve: terraform
# prompts for interactive confirmation, which is intentional for one-fabric
# blast-radius operations.
apply-kelley: render-kelley
	terraform apply -input=false $(TARGETS_Kelley)

apply-deldin: render-deldin
	terraform apply -input=false $(TARGETS_DelDin)

destroy: render
	terraform plan -destroy -out=$(DESTROY_FILE) -input=false -var-file=$(TFVARS_FILE)
	terraform apply -input=false $(DESTROY_FILE)

destroy-kelley: render-kelley
	terraform plan -destroy -out=$(DESTROY_FILE) $(TARGETS_Kelley) -input=false -var-file=$(TFVARS_FILE)
	terraform apply -input=false $(DESTROY_FILE)

destroy-deldin: render-deldin
	terraform plan -destroy -out=$(DESTROY_FILE) $(TARGETS_DelDin) -input=false -var-file=$(TFVARS_FILE)
	terraform apply -input=false $(DESTROY_FILE)

clean:
	rm -f $(PLAN_FILE) $(DESTROY_FILE) plan.txt plan.json plan_gitlab.json
	rm -f $(RENDERED_Kelley) $(RENDERED_DelDin)

# auth-check delegates to scripts/auth-check.sh. Empty FABRIC == both fabrics.
auth-check:
	@$(AUTH_CHECK) $(FABRIC)

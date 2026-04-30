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
#                                     (covers AEDCG and AEDCK)
#   make apply                     -- terraform apply plan.tfplan (BOTH fabrics)
#   make apply-aedcg               -- apply only AEDCG  (-target=module.aci_aedcg
#                                                        + module.aci_mcp_aedcg)
#   make apply-aedck               -- apply only AEDCK
#   make destroy                   -- destroy BOTH fabrics
#   make destroy-aedcg             -- destroy only AEDCG
#   make destroy-aedck             -- destroy only AEDCK
#   make render                    -- render BOTH fabrics' VMM YAML
#   make render-aedcg              -- render only AEDCG VMM YAML
#   make render-aedck              -- render only AEDCK VMM YAML
#   make auth-check                -- POST aaaLogin to BOTH fabrics
#   make auth-check FABRIC=aedcg   -- probe AEDCG only
#   make auth-check FABRIC=aedck   -- probe AEDCK only
#   make clean                     -- remove rendered YAMLs and tfplan files
#
# Required env vars (the GitLab CI pipeline uses the same names under the hood):
#   TF_VAR_aedcg_apic_password     -- AEDCG admin password
#   TF_VAR_aedck_apic_password     -- AEDCK admin password
#   TF_VAR_aedcg_mcp_key           -- AEDCG MCP key (>=8 char, mixed classes)
#   TF_VAR_aedck_mcp_key           -- AEDCK MCP key (>=8 char, mixed classes)
#   TF_VAR_vcenter_hostname_ip     -- shared vCenter (both fabrics today)
#   TF_VAR_vcenter_datacenter
#   TF_VAR_vcenter_username
#   TF_VAR_vcenter_password
#   TF_VAR_vcenter_dvs_version

.PHONY: init fmt validate plan apply apply-aedcg apply-aedck \
        destroy destroy-aedcg destroy-aedck \
        render render-aedcg render-aedck \
        clean check-env check-env-aedcg check-env-aedck auth-check

RENDER         := ./scripts/render-vmm-yaml.sh
AUTH_CHECK     := ./scripts/auth-check.sh
RENDERED_AEDCG := ../data/nac-aci-aedcg-rendered/vmm-domain.nac.yaml
RENDERED_AEDCK := ../data/nac-aci-aedck-rendered/vmm-domain.nac.yaml
PLAN_FILE      := plan.tfplan
DESTROY_FILE   := destroy.tfplan

# Module groupings for -target dispatch on partial-fabric apply/destroy.
TARGETS_AEDCG := -target=module.aci_aedcg -target=module.aci_mcp_aedcg
TARGETS_AEDCK := -target=module.aci_aedck -target=module.aci_mcp_aedck

# Shared (vCenter) env vars -- needed by both fabrics' render step.
SHARED_ENV := TF_VAR_vcenter_hostname_ip \
              TF_VAR_vcenter_datacenter \
              TF_VAR_vcenter_username \
              TF_VAR_vcenter_password \
              TF_VAR_vcenter_dvs_version

# Per-fabric env vars consumed by Terraform.
AEDCG_ENV := TF_VAR_aedcg_apic_password TF_VAR_aedcg_mcp_key
AEDCK_ENV := TF_VAR_aedck_apic_password TF_VAR_aedck_mcp_key

# Pass FABRIC=aedcg or FABRIC=aedck to scope auth-check; empty == both.
FABRIC ?=

check-env-aedcg:
	@missing=""; \
	for v in $(SHARED_ENV) $(AEDCG_ENV); do \
	    eval val=\$$$$v; \
	    if [ -z "$$val" ]; then missing="$$missing $$v"; fi; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "Missing AEDCG env var(s):$$missing" >&2; \
	    echo "Export them before running make. See README section 4." >&2; \
	    exit 1; \
	fi

check-env-aedck:
	@missing=""; \
	for v in $(SHARED_ENV) $(AEDCK_ENV); do \
	    eval val=\$$$$v; \
	    if [ -z "$$val" ]; then missing="$$missing $$v"; fi; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "Missing AEDCK env var(s):$$missing" >&2; \
	    echo "Export them before running make. See README section 4." >&2; \
	    exit 1; \
	fi

check-env: check-env-aedcg check-env-aedck

render-aedcg: check-env-aedcg
	@$(RENDER) aedcg

render-aedck: check-env-aedck
	@$(RENDER) aedck

render: render-aedcg render-aedck

init:
	terraform init -input=false

fmt:
	terraform fmt -check -recursive

validate: render
	terraform init -backend=false -input=false
	terraform validate

plan: render
	terraform plan -out=$(PLAN_FILE) -input=false

apply: render
	terraform apply -input=false $(PLAN_FILE)

# Partial applies use -target so you can promote AEDCG to production while
# AEDCK is still being validated, or vice versa. No -auto-approve: terraform
# prompts for interactive confirmation, which is intentional for one-fabric
# blast-radius operations.
apply-aedcg: render-aedcg
	terraform apply -input=false $(TARGETS_AEDCG)

apply-aedck: render-aedck
	terraform apply -input=false $(TARGETS_AEDCK)

destroy: render
	terraform plan -destroy -out=$(DESTROY_FILE) -input=false
	terraform apply -input=false $(DESTROY_FILE)

destroy-aedcg: render-aedcg
	terraform plan -destroy -out=$(DESTROY_FILE) $(TARGETS_AEDCG) -input=false
	terraform apply -input=false $(DESTROY_FILE)

destroy-aedck: render-aedck
	terraform plan -destroy -out=$(DESTROY_FILE) $(TARGETS_AEDCK) -input=false
	terraform apply -input=false $(DESTROY_FILE)

clean:
	rm -f $(PLAN_FILE) $(DESTROY_FILE) plan.txt plan.json plan_gitlab.json
	rm -f $(RENDERED_AEDCG) $(RENDERED_AEDCK)

# auth-check delegates to scripts/auth-check.sh. Empty FABRIC == both fabrics.
auth-check:
	@$(AUTH_CHECK) $(FABRIC)

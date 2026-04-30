# apic-vmware-prod Makefile
#
# Production sister of ../apic-vmware/Makefile. Functionally identical:
# wraps terraform around the per-fabric render step, with the same set of
# targets and the same FABRIC=aedcg|aedck dispatch for partial applies.
# Different output paths (../data/nac-aci-<fabric>-prod-rendered/), state,
# and (almost certainly) different APIC/MCP/vCenter env-var values.
#
# Usage:
#   make init                      -- terraform init
#   make fmt                       -- terraform fmt -check -recursive
#   make validate                  -- render BOTH fabrics + init (no backend) + validate
#   make plan                      -- render BOTH fabrics + plan -out=plan.tfplan
#   make apply                     -- terraform apply plan.tfplan
#   make apply-aedcg               -- apply only AEDCG (-target dispatch)
#   make apply-aedck               -- apply only AEDCK
#   make destroy                   -- destroy BOTH fabrics
#   make destroy-aedcg             -- destroy only AEDCG
#   make destroy-aedck             -- destroy only AEDCK
#   make render                    -- render BOTH fabrics' VMM YAML
#   make render-aedcg              -- render only AEDCG VMM YAML
#   make render-aedck              -- render only AEDCK VMM YAML
#   make auth-check                -- POST aaaLogin to BOTH production APICs
#   make auth-check FABRIC=aedcg   -- AEDCG only
#   make auth-check FABRIC=aedck   -- AEDCK only
#   make cleanup-old-vmm           -- DELETE legacy VMM domain on BOTH APICs
#                                     (override OLD_DOMAIN if not the default)
#   make clean                     -- remove rendered YAMLs and tfplan files
#
# Required env vars (matches the prod GitLab CI variable set):
#   TF_VAR_aedcg_apic_password   -- AEDCG production APIC admin password
#   TF_VAR_aedck_apic_password   -- AEDCK production APIC admin password
#   TF_VAR_aedcg_mcp_key         -- AEDCG production MCP key
#   TF_VAR_aedck_mcp_key         -- AEDCK production MCP key
#   TF_VAR_vcenter_hostname_ip
#   TF_VAR_vcenter_datacenter
#   TF_VAR_vcenter_username
#   TF_VAR_vcenter_password
#   TF_VAR_vcenter_dvs_version

.PHONY: init fmt validate plan apply apply-aedcg apply-aedck \
        destroy destroy-aedcg destroy-aedck \
        render render-aedcg render-aedck \
        clean check-env check-env-aedcg check-env-aedck \
        auth-check cleanup-old-vmm

RENDER         := ./scripts/render-vmm-yaml.sh
AUTH_CHECK     := ./scripts/auth-check.sh
CLEANUP        := ./scripts/cleanup-old-vmm-domain.sh
RENDERED_AEDCG := ../data/nac-aci-aedcg-prod-rendered/vmm-domain.nac.yaml
RENDERED_AEDCK := ../data/nac-aci-aedck-prod-rendered/vmm-domain.nac.yaml
PLAN_FILE      := plan.tfplan
DESTROY_FILE   := destroy.tfplan

TARGETS_AEDCG := -target=module.aci_aedcg -target=aci_rest_managed.mcp_inst_pol_aedcg
TARGETS_AEDCK := -target=module.aci_aedck -target=aci_rest_managed.mcp_inst_pol_aedck

SHARED_ENV := TF_VAR_vcenter_hostname_ip \
              TF_VAR_vcenter_datacenter \
              TF_VAR_vcenter_username \
              TF_VAR_vcenter_password \
              TF_VAR_vcenter_dvs_version

AEDCG_ENV := TF_VAR_aedcg_apic_password TF_VAR_aedcg_mcp_key
AEDCK_ENV := TF_VAR_aedck_apic_password TF_VAR_aedck_mcp_key

FABRIC ?=
OLD_DOMAIN ?=

check-env-aedcg:
	@missing=""; \
	for v in $(SHARED_ENV) $(AEDCG_ENV); do \
	    eval val=\$$$$v; \
	    if [ -z "$$val" ]; then missing="$$missing $$v"; fi; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "Missing AEDCG (prod) env var(s):$$missing" >&2; \
	    echo "Export them before running make. See README cutover section." >&2; \
	    exit 1; \
	fi

check-env-aedck:
	@missing=""; \
	for v in $(SHARED_ENV) $(AEDCK_ENV); do \
	    eval val=\$$$$v; \
	    if [ -z "$$val" ]; then missing="$$missing $$v"; fi; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "Missing AEDCK (prod) env var(s):$$missing" >&2; \
	    echo "Export them before running make. See README cutover section." >&2; \
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

auth-check:
	@$(AUTH_CHECK) $(FABRIC)

# cleanup-old-vmm: pass OLD_DOMAIN=<name> on the make command line if the
# production legacy domain is not `vmm-vcenter-rcc`.
cleanup-old-vmm:
	@OLD_DOMAIN="$(OLD_DOMAIN)" $(CLEANUP) $(FABRIC)

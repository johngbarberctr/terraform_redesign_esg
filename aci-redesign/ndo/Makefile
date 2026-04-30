# aci-redesign/ndo Makefile
#
# Thin wrapper around terraform for the NDO-managed tenant root. Pairs with
# the sibling apic-vmware/Makefile, which targets the APICs directly. There
# is intentionally no `render` step here: NDO YAML is hand-written and does
# not depend on any vCenter substitution.
#
# Usage:
#   make init         -- terraform init (one-time / after module bumps)
#   make fmt          -- terraform fmt -check -recursive
#   make validate     -- init -backend=false + validate
#   make plan         -- terraform plan -out=plan.tfplan
#   make apply        -- terraform apply plan.tfplan
#   make destroy      -- destroy everything in this root (does NOT touch APIC
#                        access/fabric policies, which live in apic-vmware/)
#   make auth-check   -- POST /login to NDO with current credentials
#   make clean        -- remove tfplan files
#
# Required env vars:
#   TF_VAR_ndo_password   -- NDO admin password
#
# All schema config is YAML in ../data/nac-ndo/.

.PHONY: init fmt validate plan apply destroy auth-check clean check-env

PLAN_FILE    := plan.tfplan
DESTROY_FILE := destroy.tfplan
NDO_ENV      := TF_VAR_ndo_password

check-env:
	@missing=""; \
	for v in $(NDO_ENV); do \
	    eval val=\$$$$v; \
	    if [ -z "$$val" ]; then missing="$$missing $$v"; fi; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "Missing NDO env var(s):$$missing" >&2; \
	    echo "Export them before running make. See README." >&2; \
	    exit 1; \
	fi

init:
	terraform init -input=false

fmt:
	terraform fmt -check -recursive

validate:
	terraform init -backend=false -input=false
	terraform validate

plan: check-env
	terraform plan -out=$(PLAN_FILE) -input=false

apply: check-env
	terraform apply -input=false $(PLAN_FILE)

destroy: check-env
	terraform plan -destroy -out=$(DESTROY_FILE) -input=false
	terraform apply -input=false $(DESTROY_FILE)

auth-check: check-env
	@./scripts/auth-check.sh

clean:
	rm -f $(PLAN_FILE) $(DESTROY_FILE) plan.txt plan.json plan_gitlab.json

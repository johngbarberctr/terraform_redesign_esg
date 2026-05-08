# aci-redesign / ndo

> **Phase 4 of the canonical end-to-end runbook.** This stack is the IPv4
> redesign tenant tree. It has hard prerequisites on Phase 1 (sibling
> repo `~/DC/ACI/ndo-terraform-nac-prod/` — creates the cross-referenced
> filter `AEDCE / VRF_Template / Any`) and Phase 3 (`../apic-vmware/` —
> creates the per-fabric VMM domains `APCG-VDS1` / `APCK-VDS1` that
> EPGs bind to).
>
> If you've never seen this repo before, **start at the umbrella
> runbook**: [`../../README_LAB.md`](../../README_LAB.md). It walks
> Phases 1 → 7 in order. This README covers what _this_ Phase 4 stack
> does and how it's wired.

NDO-managed tenant root for the IPv4 redesign. Uses the
`netascode/nac-ndo/mso` (NAC-NDO) module to push a single-template
schema from YAML; NDO then deploys to AEDCG and AEDCK APICs (manual
click after each Terraform `apply`).

---

## Table of Contents

1. [What this project does](#what-this-project-does)
2. [What gets built](#what-gets-built)
3. [What lives here vs. ../apic-vmware/](#what-lives-here-vs-apic-vmware)
4. [Prerequisites](#prerequisites)
5. [First-time setup (laptop)](#first-time-setup-laptop)
6. [Day-to-day workflow (laptop)](#day-to-day-workflow-laptop)
7. [Manual deploy in NDO UI](#manual-deploy-in-ndo-ui)
8. [CI/CD pipeline](#cicd-pipeline)
9. [Configuration reference](#configuration-reference)
10. [Repo layout](#repo-layout)
11. [Cutover from APIC-direct to NDO (lab one-time)](#cutover-from-apic-direct-to-ndo-lab-one-time)
12. [Troubleshooting](#troubleshooting)

---

## What this project does

When you `terraform apply` against this root:

1. Terraform reads `main.tf`, which calls the `netascode/nac-ndo/mso` module v1.2.x.
2. The module reads the YAML in `../data/nac-ndo/`:
   - `tenant.nac.yaml` — references tenant `EUR` and sites AEDCG/AEDCK.
   - `schema-aedce-ipv4.nac.yaml` — the full schema definition (single template `Tenant_EUR_IPv4`).
3. The MSO provider connects to NDO using credentials from `terraform.tfvars` (URL/user) + `TF_VAR_ndo_password` (password from env or secret store).
4. Terraform creates / updates these objects in NDO:
   - **Schema `AEDCE-IPv4`** with one template `Tenant_EUR_IPv4`
   - 2 VRFs (`VRF-EUR`, `VRF-DMZ`) with vzAny enforced
   - 2 contracts (`Any_VRF-EUR`, `Any_VRF-DMZ`) cross-referencing filter `AEDCE / VRF_Template / Any`
   - 39 stretched BDs (`l2_stretch = true` is the NAC default)
   - 2 ANPs (`AppProf-AppCentric`, `AppProf-DMZ`) with 39 EPGs total
   - VMware VMM bindings on every EPG to `APCG-VDS1` on AEDCG and `APCK-VDS1` on AEDCK
5. **Templates are NOT pushed to fabrics automatically.** `deploy_templates = false` is deliberate — you click **Deploy to sites** in the NDO UI when you're ready, see [Manual deploy in NDO UI](#manual-deploy-in-ndo-ui).

This stack does **not** own:

- Tenant `EUR` itself (Phase 1's `nac-prod` stack created it; we reference it).
- Filter `Any` (Phase 1's `AEDCE / VRF_Template / Any` is cross-referenced from this schema's contracts).
- L3Outs / External EPGs (Phase 1's `G-Specific_Only` and `K-Specific_Only` templates carry north-south routing).
- Static-port bindings (Phase 6 — `../scripts/deploy_bindings.py` PATCHes them in via the NDO REST API).

---

## What gets built

Schema **`AEDCE-IPv4`** in tenant **`EUR`** (referenced, not created), single template **`Tenant_EUR_IPv4`** deployed to sites **AEDCG** and **AEDCK**:

| Type | Count | Notes |
|------|------:|-------|
| VRFs | 2 | `VRF-EUR` (production), `VRF-DMZ`. Both enforce vzAny + permit-all. |
| Contracts | 2 | `Any_VRF-EUR`, `Any_VRF-DMZ` — cross-ref filter `AEDCE / VRF_Template / Any`. |
| Bridge Domains | 39 | `l2_stretch = true` by default; subnets per BD. |
| ANPs | 2 | `AppProf-AppCentric`, `AppProf-DMZ`. |
| EPGs | 39 | Each bound to `APCG-VDS1` (AEDCG) + `APCK-VDS1` (AEDCK) VMM domains. |
| VMM domain bindings | 78 | EPG × per-fabric VMM = 39 × 2. |

Static-port bindings are **not** modeled here — `staticPorts[]` are PATCHed in by `../scripts/deploy_bindings.py` (Phase 6) after this template is deployed to the APICs.

ESGs are **not** in NDO yet. The `nac-ndo` wrapper module doesn't ship ESG support; vzAny + permit-all on each VRF replaces them functionally.

---

## What lives here vs. `../apic-vmware/`

| Layer | Where it lives | Why |
|---|---|---|
| Access policies, fabric policies, switch/leaf profiles | `../apic-vmware/` | Per-fabric infrastructure — AAEP, VPCs, leaf profiles differ. |
| MCP instance policy | `../apic-vmware/` | Fabric-local; per-site shared key. |
| VMware VMM domain object (`vmmDomP`) | `../apic-vmware/` | Lives on each APIC; this stack references it but does not create it. |
| Tenant `EUR` (creation) | `~/DC/ACI/ndo-terraform-nac-prod/` (Phase 1) | Single tenant; Phase 1 owns it. We `manage_tenants = false` and reference by name. |
| Schema `AEDCE` (Phase 1 schema) | `~/DC/ACI/ndo-terraform-nac-prod/` (Phase 1) | Provides `VRF_Template / Any` filter and the L2/L3 templates the IPv6 layer extends. |
| Schema `AEDCE-IPv4` (this stack) | here, `../data/nac-ndo/schema-aedce-ipv4.nac.yaml` | Single template `Tenant_EUR_IPv4` with all VRFs, BDs, EPGs, ANPs, contracts. |
| Static-port bindings | `../scripts/deploy_bindings.py` (Phase 6) | NAC YAML doesn't model `staticPorts[]`; we PATCH them in via NDO REST. |

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Terraform | >= 1.5 | Any recent version. |
| `mso` provider | `CiscoDevNet/mso ~> 1.6` | Pinned in `main.tf`. |
| `netascode/nac-ndo/mso` module | `~> 1.2.0` | Downloaded by `terraform init`. |
| Network access to NDO | port 443 (HTTPS) | From the machine running Terraform. |
| Phase 1 already applied + deployed | tenant `EUR`, schema `AEDCE`, template `VRF_Template` deployed to both sites | Without this, `terraform plan` fails to resolve the cross-schema filter reference. |
| Phase 3 already applied + deployed | VMM domains `APCG-VDS1` (AEDCG) and `APCK-VDS1` (AEDCK) | Without these, EPG VMM bindings fail. |

NDO sites **AEDCG** and **AEDCK** must already be onboarded in NDO before running this project.

---

## First-time setup (laptop)

```bash
cd ~/DC/ACI/terraform-esg/aci-redesign/ndo

# 1. Choose state backend: HTTP (CI) or local (laptop). For laptop runs,
#    drop a gitignored local_override.tf so Terraform uses a local state
#    file instead of trying to talk to GitLab. (`*_override.tf` is in
#    .gitignore at the repo root — never reaches CI.)
ls local_override.tf >/dev/null 2>&1 || cat > local_override.tf <<'EOF'
terraform {
  backend "local" {}
}
EOF

# 2. Non-sensitive credentials in terraform.tfvars (gitignored).
test -f terraform.tfvars || cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
# Set: ndo_url, ndo_username, ndo_platform ("nd" for ND-hosted),
#      ndo_domain ("local" for lab admin, "DefaultAuth" for prod svc-acct)

# 3. NDO password (env var, never in tfvars). Per-shell.
source scripts/set-ndo-password.sh    # prompts for password; exports TF_VAR_ndo_password

# 4. Sanity check — POST /login to NDO with the credentials Terraform
#    will use. Fails fast with a useful message if anything is wrong.
make auth-check

# 5. Init + validate.
make init
make validate
```

---

## Day-to-day workflow (laptop)

```bash
cd ~/DC/ACI/terraform-esg/aci-redesign/ndo

# Re-source the password (TF_VAR_ndo_password is per-shell)
source scripts/set-ndo-password.sh

make plan     # writes plan.tfplan + prints diff
make apply    # consumes plan.tfplan
```

`make` wraps `terraform plan -out=plan.tfplan` and `terraform apply plan.tfplan`. The Makefile fails fast if `TF_VAR_ndo_password` is unset.

After `make apply` succeeds, the schema content is **in NDO** but the template is **not yet deployed to AEDCG/AEDCK**. Continue with [Manual deploy in NDO UI](#manual-deploy-in-ndo-ui).

---

## Manual deploy in NDO UI

NDO UI → **Application Management → Schemas → AEDCE-IPv4 → `Tenant_EUR_IPv4` → Deploy to sites** → check both **AEDCG** and **AEDCK** → **Deploy**.

There is **only one template** in this schema; older docs that mention `Tenant_Policy / Stretched_BDs / App_Profiles` reflect an abandoned three-template design. If you see those names, the docs predate the consolidation.

After the template deploys green to both sites, EPGs exist on the APICs and VMM bindings should resolve port-groups in vCenter under each VDS. Static-port bindings are still missing — that's Phase 6.

---

## CI/CD pipeline

`.gitlab-ci.yml` defines three stages: `validate → plan → apply (manual)`. Same shape as every other Terraform root in this repo. The umbrella orchestrator at `terraform-esg/.gitlab-ci.yml` includes this file via `rules: exists:`, so this project's pipeline only runs if its CI file is committed.

| Stage | Job | Trigger |
|-------|-----|---------|
| `validate` | `terraform fmt -check` + `terraform init -backend=false` + `terraform validate` | every push and MR that changes `aci-redesign/ndo/**` or `aci-redesign/data/nac-ndo/**` |
| `plan` | `terraform init` + `terraform plan -out=plan.tfplan` + JSON/text artifacts | same triggers as `validate` |
| `deploy` (`apply`) | `terraform init` + `terraform apply plan.tfplan` + tail-print of the manual NDO-UI deploy step | **manual button** in GitLab UI; only on `main` |

After clicking apply, do the manual NDO-UI deploy in [the section above](#manual-deploy-in-ndo-ui) — the apply job's tail log prints the exact UI path.

### State backend (CI)

CI uses the GitLab HTTP backend at `${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/aci-redesign-ndo`, authenticated with `gitlab-ci-token` / `${CI_JOB_TOKEN}`. **No PAT required, no expiry to manage.** The `.aci-redesign-ndo-vars` anchor in `.gitlab-ci.yml` pins these values directly; project-level `TF_HTTP_*` variables are not used.

### Required GitLab CI/CD variables

Set on the GitLab project (Settings → CI/CD → Variables):

| Variable | Purpose | Masked + Protected |
|---|---|---|
| `NDO_URL` | NDO URL (e.g. `https://198.18.133.100`) | No |
| `NDO_USERNAME` | NDO username (e.g. `admin`) | No |
| `NDO_PASSWORD` | NDO password | **Yes** |

The per-job `*-vars` anchor maps each to its `TF_VAR_*` equivalent so Terraform reads them without any shell `export`. `GITLAB_API_URL` defaults to `${CI_API_V4_URL}`.

### Triggering the pipeline

| What you do | What runs |
|---|---|
| Push / MR that changes `aci-redesign/ndo/**` or `aci-redesign/data/nac-ndo/**` | `validate` → `plan` (apply gated on `main`) |
| Merge to `main` | `validate` → `plan` → `apply` (manual button — never auto) |
| GitLab UI → **Run pipeline** with `PROJECT=aci-redesign-ndo` | only this project's jobs queue, regardless of which files changed |

---

## Configuration reference

### `main.tf` flags

```hcl
module "ndo" {
  source  = "netascode/nac-ndo/mso"
  version = "~> 1.2.0"

  yaml_directories = ["../data/nac-ndo"]

  manage_system            = false
  manage_sites             = false
  manage_site_connectivity = false
  manage_tenants           = false   # tenant EUR is owned by Phase 1
  manage_schemas           = true    # this is the only thing we manage
  deploy_templates         = false   # operator-driven via NDO UI
}
```

| Flag | Value | Why |
|------|-------|-----|
| `manage_system` | `false` | NDO system / banner is owned by Phase 1. |
| `manage_sites` | `false` | AEDCG/AEDCK pre-onboarded; we only reference them. |
| `manage_site_connectivity` | `false` | IPN/site connectivity is owned outside Terraform. |
| `manage_tenants` | `false` | Tenant `EUR` is owned by Phase 1 (`nac-prod`). To take ownership here, flip to `true` and `terraform import 'module.ndo.module.tenants[0].mso_tenant.tenant["EUR"]' EUR`. |
| `manage_schemas` | `true` | Schema `AEDCE-IPv4` and template `Tenant_EUR_IPv4` are this stack's responsibility. |
| `deploy_templates` | `false` | Push to AEDCG/AEDCK is operator-driven via the NDO UI, see [Manual deploy in NDO UI](#manual-deploy-in-ndo-ui). |

### Required environment variables (laptop)

| Variable | Required | Purpose |
|----------|----------|---------|
| `TF_VAR_ndo_password` | yes | NDO admin password. Use `scripts/set-ndo-password.sh`. |

`ndo_url`, `ndo_username`, `ndo_platform`, `ndo_domain`, `ndo_insecure` come from `terraform.tfvars`.

---

## Repo layout

```
aci-redesign/ndo/
├── README.md                       # This file
├── README_LAB.md                   # Lab daily-driver walkthrough
├── main.tf                         # netascode/nac-ndo/mso module call (declares HTTP backend)
├── local_override.tf               # Optional, gitignored — overrides backend to "local" for laptop
├── providers.tf                    # mso provider (insecure TLS for self-signed lab certs)
├── variables.tf                    # ndo_* variables
├── terraform.tfvars                # Non-sensitive credentials (gitignored)
├── terraform.tfvars.example        # Committed template; copy to terraform.tfvars
├── Makefile                        # init / fmt / validate / plan / apply / destroy / auth-check
├── .gitlab-ci.yml                  # Per-project CI: validate → plan → apply (manual)
└── scripts/
    ├── auth-check.sh               # POST /login to NDO with current creds
    └── set-ndo-password.sh         # Source to export TF_VAR_ndo_password
```

YAML lives one level up:

```
../data/nac-ndo/
├── tenant.nac.yaml                 # tenant EUR + site associations (AEDCG, AEDCK)
└── schema-aedce-ipv4.nac.yaml      # consolidated schema (single template Tenant_EUR_IPv4)
```

Generated/runtime files (all gitignored):

- `terraform.tfstate*` — Terraform state and backups (only present when using the local backend via `local_override.tf`)
- `local_override.tf` — laptop-only file that switches Terraform to the local backend
- `plan.tfplan`, `destroy.tfplan` — disposable plan artifacts
- `.terraform/` — provider and module cache

---

## Cutover from APIC-direct to NDO (lab one-time)

The IPv4 tenant tree was previously created directly on the APICs by `../apic-vmware/`. Lab is a clean-slate environment, so the move is destructive: there is no Terraform state hand-off because the resources live in different roots and were created by different providers.

1. In `../apic-vmware/`, `manage_tenants = false` is already set on both fabric modules. Run `make apply` there. The APIC-direct providers delete tenant `EUR` and its children (VRFs, BDs, EPGs, ESGs, contracts, filters, ANPs) on both AEDCG and AEDCK. Access/fabric/MCP/VMM-domain objects are untouched.
2. Sanity-check that NDO still sees both sites and AEDCG/AEDCK show healthy.
3. From this root: `make plan` then `make apply`. NDO creates schema `AEDCE-IPv4` and template `Tenant_EUR_IPv4`.
4. NDO UI → **Schemas → AEDCE-IPv4 → Tenant_EUR_IPv4 → Deploy to sites** → AEDCG + AEDCK.
5. Verify in NDO UI and on each APIC that EPG-to-VMM bindings resolved and endpoints are learning.

NDO undeploy ordering is automatic on destroy.

---

## Troubleshooting

For lab-specific issues (auth-check 401, mass-destruction plans, stale `.terraform/`), see [`README_LAB.md` → Troubleshooting](README_LAB.md#troubleshooting).

For "Duplicate Resource: …" errors on first CI apply against an empty GitLab state slot when NDO already contains the schema (because someone applied locally, or a previous CI run was wiped): migrate your local `terraform.tfstate` into the GitLab slot using `terraform init -migrate-state -force-copy` with the HTTP backend flags. See the umbrella [`README_LAB.md` → State backend (lab vs CI)](../../README_LAB.md#state-backend-lab-vs-ci) for the recovery pattern shared by all four projects in this repo.

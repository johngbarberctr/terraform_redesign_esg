# LAB - ACI Redesign (aci-redesign)

Reference configurations, blueprints, and Terraform projects for the ACI network redesign. Contains NAC YAML blueprints (both NDO and direct-APIC formats), migration phase plans, and VMware VMM domain integration via the `netascode/nac-aci` Terraform module.

---

## Two-root architecture (read this first)

The IPv4 redesign is split across **two Terraform roots** that each own one
control plane:

| Root              | Control plane | Owns                                                                                  |
| ----------------- | ------------- | ------------------------------------------------------------------------------------- |
| `apic-vmware/`    | APIC (per fabric, two providers via aliases) | Access/fabric policies (leaf profiles, AAEP, VPC, VLAN pools), MCP instance policy, VMware VMM domain (`vmmDomP`). |
| `ndo/`            | NDO (one Multi-Site control plane)           | Tenant `EUR`, VRFs (VRF-EUR / VRF-DMZ with vzAny), filter `Any`, contracts, all 39 stretched BDs, ANPs, EPGs, EPG-to-VMM-domain bindings. |

Why split: ACI tenant policy belongs in NDO when there's more than one site
(it's the only tool that does cross-site policy stitching cleanly), but
APIC-side fabric infrastructure (leaf profiles, VMM domain object) is per-
fabric and not modelable in NDO. So we drive each layer from the right tool
and keep the two roots independent of each other.

Cutover order on a clean lab: apply `apic-vmware/` first (with
`manage_tenants = false`, which is now the default), then apply `ndo/`. NDO
references the VMM domain that `apic-vmware/` created on each APIC. The
deprecated APIC-direct tenant YAML is parked at `data/_archive/tenant-epg-
nac.nac.yaml.archived` for diff/audit only -- not loaded by either root.

The remainder of this README focuses on `apic-vmware/`. For the NDO root see
[`ndo/README.md`](ndo/README.md). For the operator runbook (NDO single-
template apply, manual deploy from the NDO UI, static-port-binding push via
`scripts/deploy_bindings.py`) see [NDO operator workflow](#ndo-operator-workflow)
below.

---

## NDO operator workflow

This is the end-to-end runbook for taking a clean (or partially built) NDO
into the IPv4 redesign target state. Read [Two-root architecture](#two-root-architecture-read-this-first)
first if you skipped it.

### Architecture summary (one paragraph)

`ndo/` Terraform builds **schema `AEDCE-IPv4`** with a single template
**`Tenant_EUR_IPv4`** in tenant `EUR`. Single template = Cisco's documented
"Approach 1" from the [NDO 4.3.1 templates overview](https://www.cisco.com/c/dam/en/us/td/docs/dcn/ndo/4x/articles-431/nexus-dashboard-orchestrator-aci-templates-overview-and-operations-431.html);
appropriate here because every BD and EPG stretches identically to AEDCG and
AEDCK, no site-local objects exist, and a single template avoids cross-
template references and the cyclical-dep validation NDO 4.0+ enforces.

Tenant `EUR` is **not** managed by this root (`manage_tenants = false`):
it already exists in NDO from the IPv6 redesign, and our schema's templates
just reference it by name. Filter `Any` is also referenced cross-schema from
`AEDCE/UpgradeTemplate1` because NDO requires unique object names per tenant.

`deploy_templates = false` is set in `ndo/main.tf` so Terraform never pushes
the schema to the APICs. Operator clicks **Deploy to sites** in the NDO UI
when ready -- see [Step 4](#step-4-deploy-from-ndo-ui-manual-click).

### Step 0 — One-time setup

```bash
cd aci-redesign/ndo

# Set NDO admin password (hidden prompt). Sets TF_VAR_ndo_password.
source scripts/set-ndo-password.sh

# Edit terraform.tfvars: set ndo_url, ndo_username, ndo_platform, ndo_domain.
# (Password is intentionally not in tfvars -- env-var precedence; see the
# secrets handling section above for why.)
$EDITOR terraform.tfvars

make init
make auth-check                 # must print 200 / token before going further
```

### Step 1 — Apply the schema (no APIC push)

```bash
cd aci-redesign/ndo
make plan
# Expect to CREATE in NDO:
#   1 schema (AEDCE-IPv4)
#   1 template (Tenant_EUR_IPv4)
#   2 VRFs (VRF-EUR + VRF-DMZ, both with vzAny)
#   2 contracts (Any_VRF-EUR + Any_VRF-DMZ; filter cross-ref to AEDCE)
#   39 BDs (with subnets where applicable)
#   2 ANPs (AppProf-NetCentric + AppProf-DMZ)
#   39 EPGs (each with VMware VMM bindings on AEDCG + AEDCK)
# No mso_tenant create (manage_tenants=false).
# No mso_schema_template_deploy_ndo create (deploy_templates=false).
make apply
```

After this, log into the NDO UI: Application Management → Schemas →
`AEDCE-IPv4`. The template `Tenant_EUR_IPv4` will show **Not Deployed** on
both AEDCG and AEDCK, with all the content listed above.

### Step 2 — Verify in the NDO UI before deploying

Quick checklist before you hit Deploy:

- Schema `AEDCE-IPv4` exists with one template `Tenant_EUR_IPv4`.
- Tenant association = `EUR`. Site associations = `AEDCG` + `AEDCK`.
- VRFs `VRF-EUR` and `VRF-DMZ` exist, both with vzAny enabled.
- Contracts `Any_VRF-EUR` and `Any_VRF-DMZ` reference filter `Any` from
  `AEDCE / UpgradeTemplate1` (cross-schema icon visible).
- 39 BDs in `bridge_domains`, 39 EPGs spread across the two ANPs.
- Each EPG's site config includes the per-fabric VMM domain
  (`APCG-VDS1` on AEDCG, `APCK-VDS1` on AEDCK) with deployment /
  resolution immediacy = immediate.

### Step 3 — Deploy from NDO UI (manual click)

In the NDO UI, on the schema page:

1. Open template `Tenant_EUR_IPv4`.
2. Click **Deploy to sites**.
3. Review the per-site preview (NDO shows what will land on each APIC).
4. Confirm. NDO pushes to AEDCG and AEDCK.

After this, tenant `EUR` on each APIC has all 39 BDs, 39 EPGs, the two VRFs,
the two contracts, vzAny on both VRFs, and the EPG-to-VMM-domain bindings.
EPGs have **no static ports** yet -- that's the next step.

### Step 4 — Push static port bindings

Static port bindings (`staticPorts` arrays on EPGs) are not modeled in
nac-ndo YAML. Hand-authoring hundreds of lines is a non-starter, so we
**dump from the live source-of-truth (the IPv6 RCC schema, `AEDCE` /
`AppProf-RCC`), review, then push** into `AEDCE-IPv4`. The 39 EPG names
in the IPv6 redesign match the IPv4 redesign exactly, so the leaf/port/vPC
paths are directly reusable; only VLAN encap differs (IPv6 uses static
3001-3500, IPv4 uses VMM-dynamic 3501-3967).

```bash
cd aci-redesign/scripts

export NDO_HOST=<ndo-ip>
export NDO_USER=admin

# Dump the IPv6 RCC bindings into deploy_bindings.py input format.
# Defaults: --source-schema AEDCE  --source-anp AppProf-RCC
#           --exclude-leaves 101,102  (border leaves, L2-only in IPv6)
#           --strip-vlan  (VMM domain assigns encap dynamically)
#           --target-schema AEDCE-IPv4  (validates EPG name parity)
./dump_bindings.py --leaves 152,153,119,191 \
                   --output current_bindings.json --dry-run     # preview
./dump_bindings.py --leaves 152,153,119,191 \
                   --output current_bindings.json               # write file

# Review current_bindings.json. Decide your VLAN strategy (see warnings
# below), edit if needed, then push:
./deploy_bindings.py current_bindings.json --no-vault --dry-run  # preview
./deploy_bindings.py current_bindings.json --no-vault            # commit
```

**VLAN strategy — read this before pushing.** `dump_bindings.py` strips the
source IPv6 VLAN by default, but `deploy_bindings.py` requires `vlan` on
every binding. Three reasonable approaches:

1. **Skip static ports entirely** for VMM-only EPGs. VMware port groups +
   VDS distribute VLANs to ESX hosts automatically. Only push static ports
   for EPGs with bare-metal endpoints (e.g. `EPG-ACAS-SCANNERS`, `EPG-NAC`).
   Filter `current_bindings.json` to those EPGs only.
2. **Auto-fill from VMM-allocated VLANs** post-deploy. After Step 3 (NDO UI
   Deploy), each EPG has a dynamic VLAN. Query NDO/APIC for the assigned
   `portEncapVlan` per EPG and inject it into each binding. This is the
   most faithful "mirror IPv6 behaviour" path.
3. **Author VLANs manually** per binding. Smallest blast radius; lowest
   throughput.

For lab cutover Approach 1 is usually enough; Approach 2 matches the IPv6
production model. Whichever you pick, run `deploy_bindings.py --dry-run`
first.

`deploy_bindings.py` auto-detects the template name (`Tenant_EUR_IPv4`)
per EPG via the `epgRef` field in NDO, so the input JSON never needs a
`template` field. The dumper sets `anp_name` per EPG (`AppProf-DMZ` for
the three proxy EPGs, `AppProf-NetCentric` for the rest); `deploy_bindings.py`
does not currently consume `anp_name` — that's metadata for your review.

### Step 5 — Re-deploy in NDO UI

The static-port adds in step 4 sit in NDO's pending-changes state until you
click Deploy again. Same procedure as step 3: schema page → template →
**Deploy to sites** → review → confirm. After this, the static ports are
live on the APICs and endpoints can be plugged in.

### Day-2 changes (after the cutover)

Editing the YAML under `data/nac-ndo/` and running `make plan && make apply`
in `ndo/` gives you a pending-changes state in NDO. Click Deploy in the UI
to push. Editing static port bindings is the same loop with
`scripts/deploy_bindings.py` followed by an NDO UI Deploy.

If you ever want Terraform itself to drive the deploy (e.g. for a CI
pipeline), flip `deploy_templates = true` in `ndo/main.tf`. Re-applying will
add the `mso_schema_template_deploy_ndo` resources without recreating any
schema content.

### Refactoring the schema (e.g. switching template strategy)

When you change the template structure (split into more templates, rename a
template, or similar), Terraform plan will compute a destroy of the old
template content and a create of the new. With `deploy_templates = false`
this is safe -- it touches NDO only -- but to avoid `Missing Ref` errors
from leftover state from earlier failed applies, the cleanest sequence is:

```bash
cd aci-redesign/ndo
make destroy     # wipes the schema content from NDO; no APIC side effect
                 # because deploy_templates=false. Tenant is untouched
                 # (manage_tenants=false).
# Now edit data/nac-ndo/schema-aedce-ipv4.nac.yaml.
make plan
make apply
```

Then redo Steps 3-5 (deploy → bindings → deploy).

---

---

## Quick Start

> **First-time setup (new machine, new project, or brand-new user)?** Jump to [Getting Started](#getting-started-new-user-setup) — it walks through clone, Python venv, Terraform install, Vault wiring, and per-file explanations.
>
> **Already set up? Use this section.**

All commands run from `aci-redesign/apic-vmware/`:

```bash
cd aci-redesign/apic-vmware
```

### Every new terminal (env vars don't survive across shells)

```bash
source scripts/set-apic-password.sh                   # hidden prompt; sets BOTH TF_VAR_aedcg_apic_password
                                                      # and TF_VAR_aedck_apic_password (same value).
                                                      # Pass `aedcg` or `aedck` to set just one.
eval "$(./scripts/generate-mcp-key.sh aedcg)"         # exports TF_VAR_aedcg_mcp_key
eval "$(./scripts/generate-mcp-key.sh aedck)"         # exports TF_VAR_aedck_mcp_key (different value)
export TF_VAR_vcenter_hostname_ip='198.18.134.80'
export TF_VAR_vcenter_datacenter='Datacenter'
export TF_VAR_vcenter_username='administrator'
export TF_VAR_vcenter_password='C1sco12345!'   # single quotes!
export TF_VAR_vcenter_dvs_version='unmanaged'  # see note in templates/vmm-domain.nac.yaml.tftpl

# Sanity-check that all 4 per-fabric vars actually landed in this shell.
# Should print 4 lines; values are masked.
env | grep -E '^TF_VAR_(aedcg|aedck)_(apic_password|mcp_key)=' | sed -E 's/=.*/=<set>/'

make auth-check                                       # both fabrics must print HTTP 200 before going further
make plan                                             # only after auth-check is green for both fabrics
```

### Normal change cycle

```bash
# Edit YAML under one of:
#   ../data/nac-aci-shared/      cross-fabric (lands on AEDCG and AEDCK)
#   ../data/nac-aci-aedcg/       AEDCG-only access policies
#   ../data/nac-aci-aedck/       AEDCK-only access policies
make plan          # renders BOTH fabrics' VMM YAML + terraform plan -> plan.tfplan
make apply         # applies plan.tfplan (touches BOTH fabrics)

# Or scope to one fabric (lab→prod promotion path):
make apply-aedcg   # apply only AEDCG (-target=module.aci_aedcg + module.aci_mcp_aedcg)
make apply-aedck   # apply only AEDCK
```

### Troubleshooting one-liners

| Command | Use when |
|---|---|
| `make auth-check` | APIC returned `Unable to authenticate` -- probes BOTH fabrics |
| `make auth-check FABRIC=aedcg` | scope auth-check to one fabric |
| `./scripts/diagnose-apic-auth.sh aedcg` | `auth-check` says 401 even after you (think you) set the password |
| `source scripts/set-apic-password.sh aedck` | fix a stale `TF_VAR_aedck_apic_password` (just one fabric) |
| `make render-aedcg` / `make render-aedck` | re-generate one fabric's VMM YAML without running terraform |
| `make clean` | wipe `plan.tfplan` / `destroy.tfplan` / rendered YAML for both fabrics |
| `make destroy-aedcg` / `make destroy-aedck` | tear down a single fabric (lab cleanup, never production) |

### What the pieces do (cheat sheet)

| Thing | What it is | When you touch it |
|---|---|---|
| `Makefile` | wraps terraform; always renders BOTH fabrics' VMM YAML before plan/apply | never -- just `make <target>` |
| `scripts/set-apic-password.sh` | **sourceable** helper: hidden prompt; default sets BOTH `TF_VAR_aedcg_apic_password` and `TF_VAR_aedck_apic_password`; arg `aedcg`/`aedck` scopes to one | once per shell |
| `scripts/generate-mcp-key.sh aedcg\|aedck` | prints `export TF_VAR_<fabric>_mcp_key=<strong-key>`; run twice (one per fabric) | once per fabric per shell |
| `scripts/render-vmm-yaml.sh aedcg\|aedck` | reads `TF_VAR_vcenter_*` + `templates/vmm-domain.nac.yaml.tftpl` -> gitignored `../data/nac-aci-<fabric>-rendered/vmm-domain.nac.yaml` | never -- `make` runs it for you |
| `scripts/auth-check.sh [aedcg\|aedck\|both]` | POSTs `aaaLogin.json` to one or both fabrics; called by `make auth-check` | when debugging auth manually |
| `scripts/diagnose-apic-auth.sh aedcg\|aedck` | compares env-var password (`[B]`) vs freshly-typed password (`[C]`) for one fabric | only when `auth-check` says 401 |
| `terraform.tfvars` | **non-sensitive only**: `aedcg_apic_url/username`, `aedck_apic_url/username` | only when APIC host changes |
| `providers.tf` | default provider = AEDCG, aliased `aci.aedck` = AEDCK | only when adding a third fabric |
| `data/nac-aci-shared/` | cross-fabric APIC-direct policy. Now contains only `modules.nac.yaml` (disable wrapper's MCP submodule). Tenant content moved to NDO -- see `data/nac-ndo/`. | rarely -- only to toggle wrapper sub-modules |
| `data/nac-ndo/` | NDO YAML (consumed by the `ndo/` root, not this one): `tenant.nac.yaml`, `schema-aedce-ipv4.nac.yaml`. | edit to change tenant/EPG/contract/BD intent |
| `data/_archive/` | deprecated YAMLs not loaded by Terraform (e.g. the old APIC-direct tenant model). | reference only |
| `data/nac-aci-aedcg/` | AEDCG-only access policies (leaf 152/153 profiles, AAEP, VPC policy group, VLAN pool) | edit when AEDCG fabric wiring changes |
| `data/nac-aci-aedck/` | AEDCK-only access policies (leaf 119+191 profiles -- non-contiguous, two single-node `node_blocks`) | edit when AEDCK fabric wiring changes |
| `data/nac-aci-<fabric>-rendered/` | gitignored; `vmm-domain.nac.yaml` rendered by `render-vmm-yaml.sh` from `TF_VAR_vcenter_*` | never -- rebuilt every `make plan` |
| `apic-vmware/main.tf` | calls the nac-aci wrapper + standalone `aci_mcp` once per fabric (4 module blocks total) | rarely -- only when adding a fabric or bumping module versions |

### Why none of the secrets are in `terraform.tfvars`

Terraform variable precedence makes values in `terraform.tfvars` **beat** `TF_VAR_*` env vars. Leaving `aedcg_apic_password` / `aedck_apic_password` / `aedcg_mcp_key` / `aedck_mcp_key` undeclared in the file means the env var always wins — which is exactly what you want for rotation and Vault wiring later. Same reasoning for the five vCenter values: they're read by `render-vmm-yaml.sh` directly from env, never become Terraform variables, and never land in state. Details in [section 4](#4-configure-apic-credentials) and [section 5](#5-configure-vcenter-connectivity-vmm-domain).

---

## Design Decisions (why this project looks weird)

Four structural choices in this project are non-obvious. A future maintainer who "cleans them up" without understanding the underlying constraint will break `terraform plan`, leak secrets to state, or get locked out of APIC. Read this once; the details are linked to the deep-dive sections below.

**1. The `aci_mcp` submodule in `netascode/nac-aci` is disabled; MCP is managed in `main.tf` directly, once per fabric.**
The wrapper unconditionally creates `uni/infra/mcpInstP-default` with a hard-coded default key of `cisco` when `manage_access_policies = true`. APIC 5.2+/6.x rejects that with `Error Code 182: Password is required for MCP Instance Policy`. We disable it via `data/nac-aci-shared/modules.nac.yaml` (`modules.aci_mcp: false`) and own the MCP policy with a sensitive `var.aedcg_mcp_key` (resp. `var.aedck_mcp_key`) per fabric, so each fabric's key flows in from env / CI / Vault and a leak of one fabric's key does not compromise the other. Details: [Why `mcp_key` lives at this layer](#why-mcp_key-lives-at-this-layer).

**2. The VMM-domain YAML is rendered by a shell script before `terraform plan`, not by a `local_file` resource.**
Rendering via `local_file` was the obvious first implementation and it fails. Any module that has `depends_on` on an un-applied resource has every internal `for_each` / `count` deferred to apply-time, which breaks plan against `nac-aci` with a wall of `Invalid count argument` / `Invalid for_each argument` errors. Moving the render step *outside* Terraform (via `scripts/render-vmm-yaml.sh`, orchestrated by the `Makefile` locally and by `.gitlab-ci.yml` in CI) makes the rendered YAML a static input available at plan time. Details: [section 5](#5-configure-vcenter-connectivity-vmm-domain) and the comment at the top of `apic-vmware/main.tf`.

**3. APIC passwords and MCP keys are NOT declared in `terraform.tfvars`.**
Terraform variable precedence puts `terraform.tfvars` *above* `TF_VAR_*` environment variables. If the file declares `aedcg_apic_password = ""` (even empty), the env var is silently ignored and `terraform plan` fails with `Authentication details not provided`. Leaving the slot undeclared in the file lets the env var win for both fabrics' four secret variables (`aedcg_apic_password`, `aedck_apic_password`, `aedcg_mcp_key`, `aedck_mcp_key`), which is the pattern Stage 2 (GitLab masked CI variables) and Stage 3 (Vault data source) both rely on. Details: [Secrets handling](#secrets-handling-env-var--ci--vault).

**4. The five vCenter values are NOT Terraform variables.**
They're consumed directly by `scripts/render-vmm-yaml.sh` from `TF_VAR_vcenter_*` env vars and substituted into the template. By design they never become Terraform variables, never enter the state file, and never appear in plan output. This is what lets us keep the vCenter service-account password out of both source and state — rotating it is `export TF_VAR_vcenter_password='...' && make plan`. Details: comment block at the top of `apic-vmware/variables.tf` and [section 5](#5-configure-vcenter-connectivity-vmm-domain).

**5. `data/` is split shared / per-fabric, with both AEDCG and AEDCK wired up in the same Terraform root via provider aliases. Tenant content lives in `data/nac-ndo/`, not `data/nac-aci-shared/`.**
The `netascode/nac-aci` module deep-merges every YAML under every `yaml_directories` entry. Per-fabric *infrastructure* policy — leaf-and-port access policies, AAEP, VPC policy group, the rendered VMM-domain YAML — lives in `data/nac-aci-<fabric>/` and `data/nac-aci-<fabric>-rendered/`. The shared `data/nac-aci-shared/` directory now holds only `modules.nac.yaml` (which disables the wrapper's MCP sub-module). Tenant intent (VRFs, BDs, EPGs, contracts) moved to `data/nac-ndo/` and is consumed by the sister `ndo/` Terraform root, not by this one. Two providers (default `aci` = AEDCG, aliased `aci.aedck` = AEDCK) and four resource blocks (two module + two MCP per fabric) push the per-fabric infrastructure design to both APICs in one `terraform plan`. Details: [Multi-fabric layout](#multi-fabric-layout-aedcg--aedck) and [`ndo/README.md`](ndo/README.md).

---

## Multi-fabric layout (AEDCG + AEDCK)

Both fabrics are wired up in this Terraform root. AEDCG is the lab control fabric (`https://198.18.134.253`), AEDCK is the second lab fabric (`https://198.18.134.254`). The same shared tenant design lands on both. Production promotion flips the URLs in `terraform.tfvars` and the corresponding GitLab CI masked variables; no code change.

### Layout today

```
data/
├── nac-aci-shared/             cross-fabric APIC-direct policy
│   └── modules.nac.yaml          turns off the wrapper's aci_mcp submodule
│                                  (tenant content moved to data/nac-ndo/)
├── nac-ndo/                    NDO-managed tenant policy (consumed by ndo/ root)
│   ├── tenant.nac.yaml           stub: EUR is referenced, not created
│   └── schema-aedce-ipv4.nac.yaml  schema AEDCE-IPv4 / template Tenant_EUR_IPv4
├── _archive/                   deprecated YAMLs (reference only)
│   └── tenant-epg-nac.nac.yaml.archived
├── nac-aci-aedcg/              AEDCG-only access/fabric policies
│   └── access-policies.nac.yaml  VLAN pool 3501-3967, AAEP, leaf 152/153 profiles, VPC PG
├── nac-aci-aedcg-rendered/     gitignored; rebuilt by `render-vmm-yaml.sh aedcg`
│   └── vmm-domain.nac.yaml       VMware VMM domain w/ vCenter creds substituted in
├── nac-aci-aedck/              AEDCK-only access/fabric policies
│   └── access-policies.nac.yaml  same shape as AEDCG; leaf nodes 119+191 (non-contiguous)
└── nac-aci-aedck-rendered/     gitignored; rebuilt by `render-vmm-yaml.sh aedck`
    └── vmm-domain.nac.yaml       same template, same vCenter (today), per-fabric output
```

`apic-vmware/main.tf` declares four module blocks plus two `moved {}` blocks for state migration:

| Module | Provider | YAML dirs | What it owns |
|---|---|---|---|
| `module.aci_aedcg` | default `aci` | shared + aedcg + aedcg-rendered | AEDCG tenant + access/fabric/VMM policy |
| `module.aci_mcp_aedcg` | default `aci` | n/a (HCL only, key from `var.aedcg_mcp_key`) | AEDCG MCP Instance Policy |
| `module.aci_aedck` | `aci.aedck` (aliased) | shared + aedck + aedck-rendered | AEDCK tenant + access/fabric/VMM policy |
| `module.aci_mcp_aedck` | `aci.aedck` (aliased) | n/a (HCL only, key from `var.aedck_mcp_key`) | AEDCK MCP Instance Policy |

The `moved {}` blocks rename the previous monolithic `module.aci` / `module.aci_mcp` to their AEDCG-suffixed names. Terraform applies these as in-place state moves; existing AEDCG state does not see a destroy/recreate or a provider reassignment because the default unaliased provider FQN stays the same.

### Lab → production promotion

The recommended path is partial-fabric apply via `-target`:

1. **Validate AEDCG in lab** as you do today: `make plan && make apply-aedcg` against the lab AEDCG APIC.
2. **Validate AEDCK in lab** independently: `make apply-aedck`. AEDCK leaf node IDs in `data/nac-aci-aedck/access-policies.nac.yaml` are currently 119 and 191 (non-contiguous, so two single-node `node_blocks`). Re-check those IDs whenever the lab gets recabled and confirm them against the production AEDCK fabric before any production apply.
3. **Promote to production** by changing `aedcg_apic_url` / `aedck_apic_url` in `terraform.tfvars` and the corresponding `AEDCG_APIC_*` / `AEDCK_APIC_*` GitLab CI masked variables. `terraform.tfvars` is gitignored, so the lab values stay local.

### Why a single Terraform root, not two

A natural reflex is "one fabric = one Terraform root", but here that buys nothing and costs a lot:

- The shared tenant design has to be authored once and deployed twice. Two roots means either symlinks (fragile) or a second copy (drift). One root with shared+per-fabric data dirs gives one source of truth.
- A `make plan` that produces a single combined plan for both fabrics is dramatically easier to review than two plans you have to mentally diff.
- State stays simple: each module's resources are scoped to its provider, so AEDCG resources live under `module.aci_aedcg.*` / `module.aci_mcp_aedcg.*` and AEDCK under `module.aci_aedck.*` / `module.aci_mcp_aedck.*`. No state-file gymnastics.
- NDO orchestrates production multi-site policy already; the per-fabric work this project does is **only** what NDO can't push (access/fabric policies, MCP, VMM). That set is small enough that splitting it across two roots is overkill.

---

## Production cutover runbook

This section is the operational checklist for cutting AEDCG + AEDCK over from the legacy IPv6/N5K-fronted design to the IPv4 redesign on Design A (UCS-FI direct attach). It assumes the lab cutover has already succeeded and that all the YAML changes have merged to `main`.

> **NOTE.** Production cutover is a coordinated change that spans the network team (this repo), the UCS team (FI uplink moves), and the virtualisation team (VDS uplink portgroups in vCenter). Schedule a maintenance window and have a rollback decision-maker on the bridge.

### Scope summary

| Layer | What changes | Source of truth |
| --- | --- | --- |
| APIC access/fabric policies | New `fi-static-vlan-pool`, `fi-aaep`, `phys-fi-domain`, `PC_FI_A` / `PC_FI_B` policy groups, leaf 152/153 (AEDCG) and 119/191 (AEDCK) split between VMM ports (8-48) and FI uplinks (eth1/6, eth1/7), per-fabric VMM domain (`APCG-VDS1`, `APCK-VDS1`). | `aci-redesign/apic-vmware-prod/` (Terraform) reading `data/nac-aci-{aedcg,aedck}-prod/`. |
| APIC tenant tree (VRFs/BDs/EPGs/contracts) | Tenant `EUR`: 2 VRFs, 39 BDs, 39 EPGs, vzAny + 2 cross-VRF contracts, EPGs bound to per-fabric VMM domains. | `aci-redesign/ndo/` (Terraform) reading `data/nac-ndo/schema-aedce-ipv4.nac.yaml`. NDO pushes to both APICs. |
| Static port bindings (non-VMM EPGs) | `EPG-LB`, `EPG-LMR`, `EPG-VHOST-MGMT` plus any prod bare-metal endpoints. | `aci-redesign/scripts/deploy_bindings.py` reading a curated JSON file (NOT in this repo yet -- see Pre-flight Step 4). |
| L3Outs / external EPGs | **No change in this cutover.** They remain in the legacy `ndo-terraform/` IPv6 schema and continue to attach to VRFs by name; both schemas share the same VRF objects on the APICs. | `ndo-terraform/` (legacy). |
| UCS / vCenter | FI uplinks physically re-cabled from N5K to ACI leaves; ESXi host VDS uplinks moved to the new APIC-managed `APCG-VDS1` / `APCK-VDS1`. | UCS team + virtualisation team. Out of scope for this repo. |

### Pre-flight (T-7 days)

1. **APIC backup snapshot, both fabrics.** From each APIC's GUI:  
   `Admin → Import/Export → Configuration → Export Policies → Create Configuration Export Policy → Configure JSON, full snapshot, Now.`  
   Confirm the snapshot landed and store the artefact ID. This is the rollback target.
2. **NDO snapshot.** `Operations → Backup` in NDO. Note the timestamp.
3. **vCenter snapshot.** Export VDS configuration for `APCG-VDS1` and `APCK-VDS1`.
4. **Generate the production bindings JSON.**
   ```bash
   cd aci-redesign/scripts
   export NDO_HOST=<prod-ndo-ip>
   export NDO_USER=admin
   ./dump_bindings.py \
       --source-schema AEDCE \
       --source-anp    AppProf-NetCentric \
       --target-schema AEDCE-IPv4 \
       --leaves        152,153,119,191 \
       --keep-vlan \
       --output prod_bindings.json
   ```
   Read-only against prod NDO. Review the summary it prints (binding totals, EPG-parity warnings, target EPGs with zero bindings). Resolve VLAN collisions (multiple legacy EPGs landing on the same `(path, target-EPG)`) before proceeding -- pick a winner per tuple.
5. **Run `terraform plan` against production end-to-end.**
   ```bash
   # Production APIC root
   cd aci-redesign/apic-vmware-prod
   make auth-check                 # confirm both APIC creds work
   make plan                       # renders VMM YAML for both fabrics, then plans
   #   - review plan.txt -- expect CREATE for fi-static-vlan-pool, fi-aaep,
   #     PC_FI_A/B policy groups, leaf-{152,153,119,191}-fi-intprof, the new
   #     leaf-*-prof switch profiles, and APCG/APCK-VDS1 VMM domains.
   #   - any DESTROY here is a red flag; stop and investigate.

   # NDO redesign root
   cd ../ndo
   make auth-check
   make plan
   #   - expect CREATE for schema AEDCE-IPv4, template Tenant_EUR_IPv4,
   #     2 VRFs, 39 BDs, 2 ANPs, 39 EPGs, 2 contracts.
   #   - DELETE on any pre-existing IPv6 schema is a bug; this root only
   #     manages AEDCE-IPv4.
   ```
6. **Verify cabling and UCS plan.** The UCS team must confirm:
   - FI-A is currently single-homed to **leaf 152 (AEDCG)** / **leaf 119 (AEDCK)** through what will become `eth1/6`.
   - FI-B is single-homed to **leaf 153 (AEDCG)** / **leaf 191 (AEDCK)** through `eth1/7`.
   - LACP is configured **mac-pin** on the FI vNIC templates (matches `port_channel_policies: mac-pinning` in the data dirs).
   - If port assignments differ in production, edit `data/nac-aci-aedcg-prod/access-policies.nac.yaml` (`leaf_interface_profiles` sections) and `data/nac-aci-aedck-prod/access-policies.nac.yaml` BEFORE running `make plan`. **Never commit a plan you didn't review against the cabling worksheet.**
7. **Check `fi-static-vlan-pool` against today's NDO state.** The pool was sourced 2026-04-29. If the cutover slips by more than ~1 week, re-pull live VLANs from NDO and diff:
   ```bash
   # Quick sanity diff (replace creds appropriately)
   curl -k -sS -u "$NDO_USER:$NDO_PASS" \
        "https://$NDO_HOST/mso/api/v1/schemas?name=AEDCE" \
       | jq '... | .staticPorts[] | .vlan' | sort -un > /tmp/vlans_live.txt
   # Compare against fi-static-vlan-pool ranges in
   # data/nac-aci-{aedcg,aedck}-prod/access-policies.nac.yaml
   ```
   Add any new VLANs to both prod data files, rerun `make plan`, get an MR review.
8. **Confirm cleanup target.** If production APICs still have a legacy VMM domain (e.g. `vmm-vcenter-rcc`) with dangling `fvRsDomAtt`, decide: remove it during the window via `make cleanup-old-vmm OLD_DOMAIN=<legacy-name>`, or leave it and let it become orphan. The cleanup script is idempotent and skips if the domain is already absent.

### Cutover sequence (T-0)

> **Communication order.** Start with the network change, then the UCS re-cable, then vCenter VDS uplink moves. Each stage is reversible until the previous stage's "Verify" step has passed.

#### Stage 1 — APIC access/fabric policies (no traffic impact yet)

```bash
cd aci-redesign/apic-vmware-prod

# Optional pre-step: clear any stale legacy VMM domain.
OLD_DOMAIN=vmm-vcenter-rcc make cleanup-old-vmm        # both fabrics, idempotent

# Apply both fabrics in one go.
make plan                                              # final review
make apply                                             # applies plan.tfplan
```

**Verify:**
- APIC GUI on each fabric: `Fabric → Access Policies → Pools → VLAN → fi-static-vlan-pool` exists with the expected ranges.
- `fi-aaep` exists and references both `phys-fi-domain` and `APCG-VDS1` / `APCK-VDS1`.
- `Fabric → Access Policies → Switches → Leaf Switches → Profiles → leaf-152-prof` (and `153`, `119`, `191`) each contain the new FI interface profile.
- No new APIC faults of `severity ≥ minor` other than the expected "interface down" on the FI uplink ports (which haven't been wired yet).

This stage adds new policies. It does **not** modify existing VMM connectivity to ESXi hosts.

#### Stage 2 — Tenant tree push via NDO

```bash
cd aci-redesign/ndo
make plan
make apply
```

Then in NDO UI:  
`Application Management → Schemas → AEDCE-IPv4 → Tenant_EUR_IPv4 → Deploy to sites`. Confirm AEDCG and AEDCK both show "Deployed".

**Verify:**
- APIC GUI on each fabric: `Tenants → EUR → Application Profiles → AppProf-NetCentric / AppProf-DMZ → 39 EPGs` present.
- Each EPG shows the per-fabric VMM domain bound to it (`APCG-VDS1` on AEDCG, `APCK-VDS1` on AEDCK), with `Resolution Immediacy = Immediate`.
- vCenter: 39 port-groups under each VDS, named `EUR|...`. Should match the lab pattern.
- 3 EPGs (`EPG-LB`, `EPG-LMR`, `EPG-VHOST-MGMT`) intentionally have **no** VMM bindings; they will land via Stage 3.

#### Stage 3 — Static port bindings

```bash
cd aci-redesign/scripts
./deploy_bindings.py prod_bindings.json --no-vault --dry-run    # final review
./deploy_bindings.py prod_bindings.json --no-vault              # PATCH NDO
```

Then in NDO UI: re-deploy the `Tenant_EUR_IPv4` template (same path as Stage 2) so the new `staticPorts[]` push to the APICs.

**Verify:**
- APIC GUI: pick three sample bindings from `prod_bindings.json`; in each EPG's "Static Ports" tab, confirm the leaf/port/VLAN matches.
- Sample one bare-metal endpoint (e.g. an F5 BIG-IP behind `EPG-LB`); confirm L2 connectivity.

#### Stage 4 — UCS / vCenter physical move

This is run by the UCS team and the vSphere admin, **not** Terraform. The required changes:

1. UCS: re-cable FI-A uplink from current N5K port to ACI leaf-152 (AEDCG) / leaf-119 (AEDCK) on `eth1/6`. Same for FI-B → leaf-153 / leaf-191 on `eth1/7`. Confirm `port-channel summary` on both FIs shows the bundle up with the new uplink.
2. vCenter: for each ESXi host behind a moved FI, migrate the VDS uplinks from the legacy VDS (whatever was there pre-redesign) to `APCG-VDS1` / `APCK-VDS1`. Use **Migrate VMs to another network** in the VDS UI to drop VMs onto the new port-groups (named per the redesign EPGs).

**Verify:**
- APIC GUI: `Fabric → Inventory → <leaf> → Interfaces → Physical → eth1/6` shows `oper-state = up` on AEDCG-152 and AEDCK-119 (and `eth1/7` up on -153/-191).
- vCenter: VMs are now on port-groups whose names match redesign EPGs.
- `fvCEp` count on the new EPGs grows as VMs are migrated.

#### Stage 5 — Decommission

Once Stages 1–4 are stable for **at least 24 hours** with no traffic anomalies:

- Remove the legacy IPv6 EPG-to-VMM bindings from the legacy schema (in `ndo-terraform/` if any are still around) -- coordinate with the legacy schema owner.
- Decommission the N5K-fronted policy on the legacy schema only after the UCS team confirms no FI is still uplinked to N5K.

### Rollback

If any verify step fails irrecoverably, abort and restore.

| If you stopped after... | Rollback action |
| --- | --- |
| Stage 1 (APIC policy push) | `cd aci-redesign/apic-vmware-prod && make destroy` (or use `apply-aedcg`/`-aedck` `-destroy` for one fabric only). All adds were additive; no existing object on the APIC was overwritten. Faults clear in <60s. |
| Stage 2 (NDO tenant push) | NDO UI: `Tenant_EUR_IPv4 → Undeploy from sites` for both AEDCG and AEDCK. Then `cd aci-redesign/ndo && make destroy` to remove the schema from NDO. Legacy IPv6 schema is unaffected (separate state, separate schema name). |
| Stage 3 (static bindings) | NDO UI: hand-remove bindings on the 3 affected EPGs, then re-deploy. `deploy_bindings.py` is additive only and does not auto-undo. |
| Stage 4 (UCS / vCenter physical) | UCS team re-cables FIs back to the N5K. vCenter admin migrates VMs back to the legacy VDS / port-groups. ACI-side policies stay in place; they're harmless if no port is up. |
| Catastrophic | Restore APIC config from the snapshot taken in Pre-flight Step 1. Restore NDO from Step 2. This is the last resort; it nukes any other concurrent change made during the window. |

### Post-cutover (T+1 day)

1. New APIC config-export snapshot on both fabrics.
2. New NDO snapshot.
3. Fault sweep on both APICs: anything `severity ≥ critical` that wasn't there pre-cutover gets a ticket.
4. Diff `prod_bindings.json` against fresh `dump_bindings.py` output to confirm no drift was introduced by hand.
5. Schedule a follow-up to revisit the deferred items: ESGs (when `nac-ndo` adds support), GEF/Transport handling, and any IPv4 redesign-specific L3Outs.

---

## Current State -- 2-VRF Redesign (VRF-EUR + VRF-DMZ)

The active deployment implements a **2-VRF architecture** replacing the legacy 11-VRF layout. All internal IPv4 EPGs consolidate into `VRF-EUR`, DMZ EPGs go into `VRF-DMZ`, and IPv6 stays in `VRF-RCC` (managed separately). ESGs group EPGs for future contract tightening; vzAny permits all traffic within each VRF initially.

### What Gets Deployed

39 BDs/EPGs matching the IPv6 RCC naming structure, with legacy IPv4 subnets consolidated under each functional BD. Each new BD inherits all IPv4 subnets from the old numeric BDs it replaces (per `docs/reports/bd_mapping_analysis.txt`). 18 BDs are IPv6-only placeholders (no IPv4 subnets yet).

```
Tenant: EUR
├── Filter: Any (permit all)
├── Contract: Any_VRF-EUR (scope: context)
├── Contract: Any_VRF-DMZ (scope: context)
│
├── VRF-EUR (Internal IPv4) -- 36 BDs / 36 EPGs
│   ├── vzAny: Any_VRF-EUR (provider + consumer)
│   ├── BD-ACAS-MGMT         (placeholder)     → EPG-ACAS-MGMT
│   ├── BD-ACAS-SCANNERS     (2 subnets)       → EPG-ACAS-SCANNERS
│   ├── BD-AD                (3 subnets)       → EPG-AD
│   ├── BD-ADM-DCO           (1 subnet)        → EPG-ADM-DCO
│   ├── BD-ADFS              (placeholder)     → EPG-ADFS
│   ├── BD-APP-SVR           (32 subnets)      → EPG-APP-SVR
│   ├── BD-BACKUP-SVR        (4 subnets)       → EPG-BACKUP-SVR
│   ├── BD-C2C-SCANNERS      (placeholder)     → EPG-C2C-SCANNERS
│   ├── BD-CFG-MGMT          (19 subnets)      → EPG-CFG-MGMT
│   ├── BD-DB-SVR            (8 subnets)       → EPG-DB-SVR
│   ├── BD-DHCP-SVR          (placeholder)     → EPG-DHCP-SVR
│   ├── BD-DNS-MGMT          (L2-only, 0 subs) → EPG-DNS-MGMT
│   ├── BD-E911-SVR          (placeholder)     → EPG-E911-SVR
│   ├── BD-FILE-SVR          (3 subnets)       → EPG-FILE-SVR
│   ├── BD-FMWR-SVR          (placeholder)     → EPG-FMWR-SVR
│   ├── BD-GEF-MGMT          (L2-only, 0 subs) → EPG-GEF-MGMT
│   ├── BD-LB                (3 subnets)       → EPG-LB
│   ├── BD-LMR               (placeholder)     → EPG-LMR
│   ├── BD-MECM              (6 subnets)       → EPG-MECM
│   ├── BD-NAC               (placeholder)     → EPG-NAC
│   ├── BD-NMS               (1 subnet)        → EPG-NMS
│   ├── BD-OCSP              (placeholder)     → EPG-OCSP
│   ├── BD-PATCH             (1 subnet)        → EPG-PATCH
│   ├── BD-PKI-SRV           (1 subnet)        → EPG-PKI-SRV
│   ├── BD-PRINT-SVR         (placeholder)     → EPG-PRINT-SVR
│   ├── BD-RCC-DCO           (placeholder)     → EPG-RCC-DCO
│   ├── BD-RCC-DNS           (placeholder)     → EPG-RCC-DNS
│   ├── BD-RCC-SVR           (placeholder)     → EPG-RCC-SVR
│   ├── BD-RCC-UNIX          (placeholder)     → EPG-RCC-UNIX
│   ├── BD-SMTP-SVR          (placeholder)     → EPG-SMTP-SVR
│   ├── BD-SYSLOG            (3 subnets)       → EPG-SYSLOG
│   ├── BD-SYSMAN            (placeholder)     → EPG-SYSMAN
│   ├── BD-VHOST-MGMT        (1 subnet)        → EPG-VHOST-MGMT
│   ├── BD-VVOIP-MGMT        (9 subnets)       → EPG-VVOIP-MGMT
│   ├── BD-VVOIP-PROXY       (1 subnet)        → EPG-VVOIP-PROXY
│   └── BD-WEB-SVR           (11 subnets)      → EPG-WEB-SVR
│
├── VRF-DMZ (DMZ -- routing-isolated from internal) -- 3 BDs / 3 EPGs
│   ├── vzAny: Any_VRF-DMZ (provider + consumer)
│   ├── BD-D64-PROXY         (placeholder)     → EPG-D64-PROXY
│   ├── BD-FWEB-PROXY        (3 subnets)       → EPG-FWEB-PROXY
│   └── BD-RWEB-PROXY        (placeholder)     → EPG-RWEB-PROXY
│
├── AppProf-NetCentric     (36 internal EPGs on per-fabric VMM domains: APCG-VDS1, APCK-VDS1)
├── AppProf-DMZ            (3 DMZ EPGs on per-fabric VMM domains: APCG-VDS1, APCK-VDS1)
└── AppProf-SecurityGroups
    ├── ESG-All-Internal-EPGs → selects all 36 internal EPGs
    └── ESG-All-DMZ-EPGs      → selects all 3 DMZ EPGs
```

**Subnet consolidation totals**: All 215 legacy IPv4 BDs are accounted for:
- **22 BDs** have IPv4 subnets (110 total subnets from 171 mapped legacy BDs)
- **17 BDs** are placeholders (IPv6-only categories with no IPv4 predecessor)
- **14 legacy BDs** are L2-only (mapped by function, no subnets -- gateway on external firewall)
- **30 legacy BDs** are decommission candidates (20 dead + 4 deprecated + 6 temp test)
- **0 unmatched**

See [`IPv4_REDESIGN_OVERVIEW.md`](IPv4_REDESIGN_OVERVIEW.md) for the full design document.

### Design Rationale

| Decision | Why |
|----------|-----|
| **2 VRFs instead of 11** | Legacy VRFs (EUR-E, EUR-AIS, EUR-AIM, etc.) provided segmentation via routing isolation. ESGs now handle segmentation with contracts, so only Internal vs DMZ routing isolation is needed. |
| **VRF-EUR (internal)** | Consolidates EUR-E (101 EPGs), EUR-AIS (132), EUR-AIM (15), EUR-AIV (12), EUR-AIZ (11), EUR-AIG (1), EUR-AIP (4), EUR-GSN-Test (1) = ~276 EPGs. |
| **VRF-DMZ** | Keeps EUR-AOV-UC-DMZ and EUR-ARMY-ENT-SVR-DMZ routing-isolated from internal. DMZ traffic must never share a routing table with internal. |
| **VRF-RCC (IPv6)** | Unchanged. Managed separately in `ndo-terraform-nac/136.215.4.96/`. |
| **Descriptive naming** | `BD-DNS-MGMT` / `EPG-DNS-MGMT` replaces numeric `BD-V0005` / `EPG-V0005`. Matches IPv6 RCC naming style. |
| **vzAny permit-all** | Initial state -- everything communicates. ESGs provide classification for progressive tightening. |
| **L3Outs** | Production consolidates from 13 L3Outs to ~4 (1 internal + 1 DMZ per site). Lab does not deploy L3Outs. |

### Naming Conventions (Production-Ready)

| Object | Pattern | Example |
|--------|---------|---------|
| VRF (internal) | `VRF-EUR` | VRF-EUR |
| VRF (DMZ) | `VRF-DMZ` | VRF-DMZ |
| VRF (IPv6) | `VRF-RCC` | VRF-RCC (unchanged) |
| Contract | `Any_<VRF>` | Any_VRF-EUR, Any_VRF-DMZ |
| Filter | `Any` | Any |
| BD | `BD-<function>` | BD-DNS-MGMT, BD-UC-DMZ |
| EPG | `EPG-<function>` | EPG-DNS-MGMT, EPG-UC-DMZ |
| App Profile (internal) | `AppProf-NetCentric` | AppProf-NetCentric |
| App Profile (DMZ) | `AppProf-DMZ` | AppProf-DMZ |
| App Profile (ESGs) | `AppProf-SecurityGroups` | AppProf-SecurityGroups |
| ESG (internal) | `ESG-All-Internal-EPGs` | ESG-All-Internal-EPGs |
| ESG (DMZ) | `ESG-All-DMZ-EPGs` | ESG-All-DMZ-EPGs |

### Migration Phases

The **lab is greenfield** -- built from scratch to validate the target design. **Production is brownfield** -- 266 EPGs across 11 VRFs with live traffic. Production migration requires coexistence, not a rebuild.

#### Lab (Greenfield)

| Phase | What | Status |
|-------|------|--------|
| 1 | Base build -- 2 VRFs, 39 BDs (with consolidated IPv4 subnets), 39 EPGs, VMM domain, vzAny -- NDO-managed via schema `AEDCE-IPv4` / template `Tenant_EUR_IPv4` | **Complete** |
| 2 | ESG grouping all EPGs per VRF (36 internal + 3 DMZ) | **Deferred** -- nac-ndo `~> 1.2.0` does not yet expose `mso_schema_template_anp_epg_selector`. Will be added once the module supports it (or via direct `mso_*` resources). |
| 3 | Split ESGs into zone-specific groups (ESG-AIM, ESG-AIS, etc.) with inter-ESG contracts | Future |
| 4 | Tighten contracts to only required flows | Future |

#### Production (Brownfield)

Existing 11 VRFs and 266 EPGs cannot be deleted and rebuilt. The migration runs in parallel with live traffic:

| Phase | What | Key Consideration |
|-------|------|-------------------|
| 1 | Create VRF-EUR and VRF-DMZ alongside existing VRFs | New VRFs coexist with old ones; no traffic impact |
| 2 | Create new BDs with descriptive names in VRF-EUR/VRF-DMZ | Old BDs remain operational; new BDs have no endpoints yet |
| 3 | Create ESGs and vzAny contracts on VRF-EUR/VRF-DMZ | Security policy ready before any endpoints move |
| 4 | Migrate EPGs one-at-a-time from old VRFs to new VRFs | Move BD from old VRF to new VRF; endpoints re-learn. Schedule per-subnet maintenance windows |
| 5 | Consolidate L3Outs (13 → ~4) | Requires routing re-convergence; coordinate with firewall/WAN teams |
| 6 | Rename EPGs/BDs from numeric to descriptive | Can be done during or after VRF migration |
| 7 | Decommission old VRFs, contracts, and L3Outs | Only after all EPGs have been migrated and validated |

**Risk areas**: BD VRF reassignment causes endpoint re-learning (brief traffic loss per subnet). L3Out consolidation affects external routing. Plan per-subnet change windows.

## Getting Started (New User Setup)

> Already set up? Use the [Quick Start](#quick-start) at the top of this README instead.

This section walks a new user through setting up everything from scratch on the RHEL production server or a local Mac. Follow once per machine / per new team member, then move to the Quick Start for day-to-day operation.

### 1. Clone the Repository

```bash
# Production (RHEL server via SSH)
cd ~
git clone https://sync.git.mil/john.g.barber.ctr/my-new-ipv6-project.git
cd my-new-ipv6-project/aci-redesign/apic-vmware

# Lab (local Mac)
cd ~/Documents
git clone http://localhost:8080/root/terraform_redesign_esg.git
cd terraform_redesign_esg/aci-redesign/apic-vmware
```

### 2. Set Up Python Virtual Environment

Python is needed if you plan to run any companion scripts. If you only need Terraform, skip to step 3.

```bash
# Create venv (one-time)
python3 -m venv ~/my_venv
source ~/my_venv/bin/activate
pip install requests urllib3
```

Activate the venv each time you open a new terminal:

```bash
source ~/my_venv/bin/activate
```

### 3. Verify Terraform Is Installed

```bash
terraform version
```

If Terraform is not found, check if it's at `/usr/bin/terraform` or ask the infrastructure team for the binary location. The project requires Terraform >= 1.0.

### 4. Configure APIC Credentials

> **IMPORTANT**: All IP addresses, URLs, usernames, and passwords shown in this README are placeholders. You **must** replace them with the actual production values for your environment (APIC IP, vCenter IP, your credentials). Ask the current project owner if you don't have the production values.

Create a `terraform.tfvars` file from the provided example:

```bash
cp terraform.tfvars.example terraform.tfvars
chmod 600 terraform.tfvars
```

Edit `terraform.tfvars` with your real APIC connection details for both fabrics:

```hcl
aedcg_apic_url      = "https://198.18.134.253"   # Replace with actual AEDCG APIC management IP
aedcg_apic_username = "admin"
aedck_apic_url      = "https://198.18.134.254"   # Replace with actual AEDCK APIC management IP
aedck_apic_username = "admin"
# DO NOT add aedcg_apic_password / aedck_apic_password / aedcg_mcp_key /
# aedck_mcp_key here -- file values beat env vars in Terraform precedence.
# Use the env-var approach below instead.
```

This file is gitignored and will not be committed. For the password/key fields, the environment-variable approach below is the only supported flow.

#### Secrets handling (env var → CI → Vault)

Four values in this stack are sensitive, two per fabric: `aedcg_apic_password`, `aedck_apic_password`, `aedcg_mcp_key`, `aedck_mcp_key` (the MCP MisCabling-Protocol Instance Policy key that APIC enforces complexity on). The project is wired so the *source* of these secrets can change without touching Terraform code.

**Stage 1 — Local developer (today).** Export the values as environment variables in your shell; Terraform picks them up automatically via `TF_VAR_<name>`. Leave the corresponding fields out of `terraform.tfvars` entirely (declaring them there — even as `""` — would override the env var).

```bash
source scripts/set-apic-password.sh           # sets BOTH aedcg + aedck to the same prompted password
                                              # (lab default; pass `aedcg`/`aedck` if they differ)
eval "$(./scripts/generate-mcp-key.sh aedcg)" # sets TF_VAR_aedcg_mcp_key
eval "$(./scripts/generate-mcp-key.sh aedck)" # sets TF_VAR_aedck_mcp_key (different value)
make apply
```

Requirements for the MCP keys: at least 8 characters, mix of upper/lower/digit/symbol. Weak values such as `cisco` are rejected by APIC with `Error Code 182: Password is required for MCP Instance Policy`. A local `length(...) >= 8` validator is included in `variables.tf` for both `aedcg_mcp_key` and `aedck_mcp_key` as a first-line check.

`generate-mcp-key.sh` takes a fabric argument (`aedcg` or `aedck`), uses `/dev/urandom` for entropy, never writes the key to disk, and avoids APIC-reserved characters (`\`, `"`, `'`, backtick, `$`, whitespace). Run it twice (once per fabric) so the two fabrics get independent keys — a leak of one does not compromise the other. Capture the printed key only in env vars, a GitLab masked CI variable, or your secrets manager.

**Stage 2 — GitLab CI/CD pipelines.** In the GitLab project (or group) settings under *Settings → CI/CD → Variables*, add:

| Key | Value | Flags |
|-----|-------|-------|
| `AEDCG_APIC_URL` | AEDCG APIC URL (e.g. `https://198.18.134.253`) | (plain) |
| `AEDCG_APIC_USERNAME` | AEDCG APIC username | (plain) |
| `AEDCG_APIC_PASSWORD` | AEDCG APIC password | Masked, Protected |
| `AEDCG_MCP_KEY` | AEDCG MCP key (≥8 chars, mixed classes) | Masked, Protected |
| `AEDCK_APIC_URL` | AEDCK APIC URL | (plain) |
| `AEDCK_APIC_USERNAME` | AEDCK APIC username | (plain) |
| `AEDCK_APIC_PASSWORD` | AEDCK APIC password | Masked, Protected |
| `AEDCK_MCP_KEY` | AEDCK MCP key (≥8 chars, mixed classes; **different** from AEDCG) | Masked, Protected |
| `VCENTER_USERNAME` | vCenter service-account username | Masked, Protected |
| `VCENTER_PASSWORD` | vCenter service-account password | Masked, Protected |
| `VCENTER_HOSTNAME_IP` | vCenter IP or FQDN (shared by both fabrics today) | (plain) |
| `VCENTER_DATACENTER` | vCenter datacenter name | (plain) |
| `VCENTER_DVS_VERSION` | vSphere VDS version (default `6.6`) | (plain) |

`.gitlab-ci.yml` maps each of the above to the corresponding `TF_VAR_*` so the same Terraform code used locally works in CI without change. The `plan-aci` and `deploy-aci` jobs run `render-vmm-yaml.sh aedcg` and `render-vmm-yaml.sh aedck` before `terraform plan`/`apply`. Never commit secret values to `.gitlab-ci.yml` or any tracked file — the `validate-aci` stage runs `.gitlab/ci-secret-scan.sh`, which fails the pipeline if it detects a plaintext `password:` literal (other than `""`, `"CHANGE_ME"`, or a `"${...}"` template placeholder) in any tracked NAC YAML, a hard-coded known-bad lab credential anywhere in the tree, or a tracked `.tfvars` file.

**Stage 3 — Vault (lab→prod parity).** When the lab Vault is available (or any KV-compatible secret store like CyberArk / AWS Secrets Manager / Azure Key Vault), swap the *source* of the variables by adding a data source and passing it through, e.g.:

```hcl
data "vault_kv_secret_v2" "aci_lab" {
  mount = "secret"
  name  = "aci/lab"
}

# In terraform.tfvars / env: no longer needed for these fields.
# Wire each fabric's data source value in:
#   aedcg_apic_password = data.vault_kv_secret_v2.aci_lab.data["aedcg_apic_password"]
#   aedcg_mcp_key       = data.vault_kv_secret_v2.aci_lab.data["aedcg_mcp_key"]
#   aedck_apic_password = data.vault_kv_secret_v2.aci_lab.data["aedck_apic_password"]
#   aedck_mcp_key       = data.vault_kv_secret_v2.aci_lab.data["aedck_mcp_key"]
```

Because all four secrets are already abstracted as sensitive Terraform variables, this move is purely a wiring change; no downstream module calls change. Use AppRole auth for Terraform runners and OIDC/userpass for humans. Do not run `vault server -dev` for anything other than throwaway experiments.

#### Why `mcp_key` lives at this layer

The `netascode/nac-aci` wrapper unconditionally creates `uni/infra/mcpInstP-default` using a hard-coded default key (`cisco`) when `manage_access_policies = true`, which APIC rejects. This project disables that sub-module via `data/nac-aci-shared/modules.nac.yaml` (`modules.aci_mcp: false`) and manages the MCP Instance Policy directly in `apic-vmware/main.tf`, with one `module "aci_mcp_<fabric>"` block per fabric so each APIC gets its own MCP key.

### 5. Configure vCenter Connectivity (VMM Domain)

The VMware VMM domain is no longer defined directly in a tracked YAML. Instead, `apic-vmware/scripts/render-vmm-yaml.sh <fabric>` renders `../data/nac-aci-<fabric>-rendered/vmm-domain.nac.yaml` from the template `apic-vmware/templates/vmm-domain.nac.yaml.tftpl` using five environment variables. The rendered directories (one per fabric) are gitignored, so the vCenter credentials never land in the repo. Both fabrics currently share the same vCenter, so the same `TF_VAR_vcenter_*` env vars feed both `render-vmm-yaml.sh aedcg` and `render-vmm-yaml.sh aedck`. If they diverge, introduce `TF_VAR_<fabric>_vcenter_*` and update the render script.

**Important:** The render step runs *outside* Terraform (via a shell script, wrapped by the `Makefile`) and must complete *before* `terraform plan`. Rendering via a `local_file` resource inside Terraform was tried and fails — any module with `depends_on` on an unapplied resource has every internal `for_each`/`count` deferred to apply-time, which breaks plan against `nac-aci`. See the comment at the top of `apic-vmware/main.tf`.

| Env var | Sensitive | Typical source |
|---------|-----------|----------------|
| `TF_VAR_vcenter_hostname_ip` | No | shell / CI variable `VCENTER_HOSTNAME_IP` |
| `TF_VAR_vcenter_datacenter` | No | shell / CI variable `VCENTER_DATACENTER` |
| `TF_VAR_vcenter_dvs_version` | No | shell / CI variable `VCENTER_DVS_VERSION` (default `unmanaged`). The `netascode/nac-aci` 0.7.0 module's validator only accepts `unmanaged`, `5.1`, `5.5`, `6.0`, `6.5`, `6.6` -- newer concrete values like `7.0`/`8.0`/`8.0.2` are rejected at plan time. `unmanaged` instructs APIC to adopt the existing per-fabric VDS at whatever version vCenter has, which is what we want for adoption. |
| `TF_VAR_vcenter_username` | **Yes** | shell / CI masked var `VCENTER_USERNAME` / Vault |
| `TF_VAR_vcenter_password` | **Yes** | shell / CI masked var `VCENTER_PASSWORD` / Vault |

Local developer workflow (single-step via Makefile):

```bash
cd aci-redesign/apic-vmware

# Export everything the workflow needs in this shell.
source scripts/set-apic-password.sh                # both aedcg + aedck (same lab pw)
eval "$(./scripts/generate-mcp-key.sh aedcg)"      # TF_VAR_aedcg_mcp_key
eval "$(./scripts/generate-mcp-key.sh aedck)"      # TF_VAR_aedck_mcp_key
export TF_VAR_vcenter_hostname_ip='198.18.134.80'
export TF_VAR_vcenter_datacenter='Datacenter'
export TF_VAR_vcenter_dvs_version='unmanaged'   # see env-var table above for why
export TF_VAR_vcenter_username='administrator'
export TF_VAR_vcenter_password='<vCenter password>'

make validate   # renders BOTH fabrics + `terraform init -backend=false` + validate
make plan       # renders BOTH fabrics + `terraform plan -out=plan.tfplan`
make apply      # `terraform apply plan.tfplan` (touches both fabrics)
```

`make` will fail fast with a clear message if any required `TF_VAR_*` is unset for the targeted fabric(s). Each `make plan` / `make apply` re-renders the YAML from the current env, so rotating a credential is just `export TF_VAR_vcenter_password='...' && make plan`.

If you prefer calling terraform directly, run `./scripts/render-vmm-yaml.sh aedcg` and `./scripts/render-vmm-yaml.sh aedck` yourself first, then `terraform plan` / `terraform apply` as usual.

Vault wiring (Stage 3) is identical to the APIC password / MCP key pattern — populate the same `TF_VAR_*` env vars from a `vault kv get` / `vault read` call in the wrapper, or replace the `make` target with one that pulls the values; no Terraform code change.

**History note**: an earlier `data/nac-aci-vmm/vmm-domain.nac.yaml` contained a plaintext vCenter password and is still in git history. If that value is still live in vCenter, rotate the password in vCenter and update the new env var / Vault secret. History rewrite (`git filter-repo`) is required if you need to erase it from past commits, and requires a force-push plus reclone for every collaborator.

### 6. Initialize Terraform

This project uses a **local state file** (not the GitLab HTTP backend). Initialize once:

```bash
cd aci-redesign/apic-vmware
make init         # wraps `terraform init -input=false`
```

After this, the `.terraform/` directory is created with the provider cache. You only need to re-run `make init` if you delete `.terraform/` or bump provider versions.

### 7. Plan and Review

```bash
# Local / quick run (renders VMM YAML, then terraform plan)
make plan

# Production server (SSH) — use nohup to survive session drops
nohup make plan > plan_output.log 2>&1 &
tail -f plan_output.log
```

`make plan` produces `plan.tfplan` in the module directory. Review `terraform show plan.tfplan` (or the `plan.txt` the CI pipeline writes). Expect ~200+ resources on first run (VRFs, BDs, EPGs, access policies, VMM domain, ESGs).

### 8. Apply

```bash
# Local / quick run (re-renders VMM YAML then applies plan.tfplan)
make apply

# Production server (SSH)
nohup make apply > apply_output.log 2>&1 &
tail -f apply_output.log
```

**If your SSH session drops**, reconnect and check on the job:

```bash
ps aux | grep terraform
tail -f apply_output.log
```

The Terraform process continues in the background regardless.

### 9. Verify

After apply completes, log in to the APIC GUI and verify:
- Tenant `EUR` exists with VRF-EUR and VRF-DMZ
- Bridge Domains and EPGs are created under the correct VRFs
- VMM domain `APCG-VDS1` (on AEDCG) and `APCK-VDS1` (on AEDCK) appear under
  Virtual Networking > VMware in each APIC. Each shows `compCtrlr.operSt = online`
  for the vCenter controller.
- Port groups appear in vCenter on the matching per-fabric VDS
  (`APCG-VDS1` / `APCK-VDS1`), one per EPG bound to the domain.

---

### Troubleshooting

**"terraform: command not found"**

Terraform is not in your PATH. Try:

```bash
export PATH="/usr/bin:$PATH"
terraform version
```

If that works, add the export to your `.bashrc` or shell profile.

**"Error: Failed to query available provider packages"**

The server cannot reach the Terraform registry. On an air-gapped system, the `.terraform/` directory with cached providers must be present. Copy it from an existing working setup or use `terraform init` on a connected machine first.

**"Error: Creation of rest request failed … Unable to authenticate"**

The ACI provider reached APIC but APIC rejected the login. The fastest way to prove whether it is a credential problem (wrong password, wrong username, bash-expanded `!`, trailing newline, locked account) or a Terraform-side problem is the bundled probe:

```bash
cd aci-redesign/apic-vmware
make auth-check                       # probes BOTH fabrics
make auth-check FABRIC=aedcg          # scope to one fabric (aedcg or aedck)
```

`make auth-check` reads `<fabric>_apic_url` + `<fabric>_apic_username` straight from `terraform.tfvars`, picks up the password from `TF_VAR_<fabric>_apic_password`, `POST`s `/api/aaaLogin.json` to each targeted APIC, and prints a per-fabric verdict:

- `HTTP 200 -- OK` → creds are fine, re-run `make plan`.
- `HTTP 401 -- BAD CREDENTIALS` → fix the password. The safest way (no quoting pitfalls, no bash history expansion, no copy-paste CR) is the bundled sourceable helper:
  ```bash
  source scripts/set-apic-password.sh           # both fabrics, same prompted password
  source scripts/set-apic-password.sh aedck     # only aedck
  make auth-check                                # should now print HTTP 200 for the targeted fabric(s)
  ```
  `source` is required — a subprocess cannot export variables into the parent shell, so `./scripts/set-apic-password.sh` (no `source`) will refuse to run. If you prefer the manual route, use **single** quotes so bash does not history-expand `!`:
  ```bash
  export TF_VAR_aedcg_apic_password='<AEDCG admin password>'
  export TF_VAR_aedck_apic_password='<AEDCK admin password>'
  ```
- `HTTP 403 -- FORBIDDEN` → the `admin` account is locked from repeated failures on that fabric. Wait 5–10 minutes or unlock via another admin in `Admin → AAA → Security → Users`.
- `HTTP 000 -- NO RESPONSE` → APIC unreachable / wrong URL / TLS broken. Validate with:
  ```bash
  curl -k -sS -o /dev/null -w 'HTTP %{http_code}' https://198.18.134.253/api/aaaLogin.json; echo
  ```

If `auth-check` keeps returning 401 even after setting the password, run `./scripts/diagnose-apic-auth.sh aedcg` (or `aedck`). It compares the env-var password (`[B]`) against a freshly-typed password (`[C]`); if `[C]` succeeds but `[B]` fails, the env var in your shell is stale and `source scripts/set-apic-password.sh` fixes it.

Neither the probe nor the helpers ever echo the password.

**"Error: ... CHANGE_ME"**

You have unedited placeholders in tracked YAML. The VMM-domain YAMLs are *not* a place to look — they're now templated and rendered out-of-band, and the rendered copies are gitignored. Search the tracked YAML directories instead:

```bash
grep -r "CHANGE_ME" ../data/nac-aci-shared/ ../data/nac-aci-aedcg/ ../data/nac-aci-aedck/
```

Replace all matches with real values. The leaf node IDs in `nac-aci-aedcg/access-policies.nac.yaml` (152, 153) and `nac-aci-aedck/access-policies.nac.yaml` (119, 191) reflect the current lab cabling and may change — verify them before any production apply.

---

## GitLab Runner

The runner is a user-local binary on the RHEL server (no sudo, no systemd). If pipelines are stuck in "pending", the runner is likely offline. There are **two servers** with runners:

| Server | Hostname | Projects |
|--------|----------|----------|
| `apckw059aau0096` | aci-automation-runner | ndo-terraform, aci-redesign |
| `APCKW059AAU0018` | — | n5k, aci-lf-rplc |

This project (`aci-redesign`) runs on **`apckw059aau0096`**.

**Step 1: SSH into the server** and verify which one you're on:

```bash
hostname
```

**Step 2: Find the runner binary** (path may vary per server):

```bash
find /home/john.g.barber.ctr -name "gitlab-runner" -type f 2>/dev/null
find /Viper -name "gitlab-runner" -type f 2>/dev/null
```

**Step 3: Check if the runner is running:**

```bash
ps aux | grep gitlab-runner | grep -v grep
```

If that returns nothing, the runner is not running.

**Step 4: Start (or restart) the runner** using the path you found in step 2:

```bash
# Start (replace path if different on your server)
nohup ~/gitlab-runner/gitlab-runner run &

# Restart (kill stale + start fresh)
pkill gitlab-runner && nohup ~/gitlab-runner/gitlab-runner run &
```

The runner should show as online in GitLab within 30 seconds.

**Auto-start on reboot** (the runner is a background process — it dies on reboot):

On `apckw059aau0096` (this project's runner):

```bash
crontab -e
# Add these lines:
@reboot nohup /home/john.g.barber.ctr/gitlab-runner/gitlab-runner run &
*/5 * * * * pgrep -f "gitlab-runner run" > /dev/null || nohup /home/john.g.barber.ctr/gitlab-runner/gitlab-runner run &
```

On `APCKW059AAU0018` (n5k/aci-lf-rplc runner):

```bash
crontab -e
# Add these lines:
@reboot nohup /home/john.g.barber.ctr/gitlab-runner run &
*/5 * * * * pgrep -f "gitlab-runner run" > /dev/null || nohup /home/john.g.barber.ctr/gitlab-runner run &
```

The `@reboot` line starts the runner after a reboot. The `*/5` line checks every 5 minutes and restarts it if it crashed.

---

## VMware VMM Integration

VMM integration uses dynamic VLAN assignment from pool **3501-3967** (avoids IPv6 range 3001-3500 and ACI reserved 3968-4095). When an EPG is bound to the VMM domain, ACI auto-assigns a VLAN from this pool and creates a port group on the VDS in vCenter.

### VLAN Strategy

| Range | Use | Allocation |
|-------|-----|------------|
| 3001-3500 | IPv6 RCC EPGs (existing static) | Static |
| **3501-3967** | **VMM domain (IPv4 EPGs)** | **Dynamic** |
| 3968-4095 | ACI reserved (do not use) | N/A |

### Production Config (Design A: UCS-FI direct attach)

The production fabric layout differs from the lab simulator because UCS Fabric
Interconnects (FIs) replace the legacy N5Ks: each leaf has a single-leaf
port-channel to one FI (FI-A↔Leaf-A, FI-B↔Leaf-B; FIs do not vPC-peer with
each other). The redesign keeps the lab and prod data dirs separate so the lab
simulator topology is never accidentally pushed against prod, or vice versa.

| Fabric | Lab data dir (consumed by `apic-vmware/`) | Prod data dir (for the future `apic-vmware-prod/` root) |
|--------|--------------------------------------------|----------------------------------------------------------|
| AEDCG  | `data/nac-aci-aedcg/`                      | `data/nac-aci-aedcg-prod/`                               |
| AEDCK  | `data/nac-aci-aedck/`                      | `data/nac-aci-aedck-prod/`                               |

The `*-prod` dirs add (vs the lab dirs):

| Object | Notes |
|--------|-------|
| `fi-static-vlan-pool` | Static VLAN pool, 213 distinct VLANs in 93 contiguous ranges -- the union of every VLAN in production NDO schema `AEDCE / AppProf-NetCentric` (sourced live). Both sites use the same union for symmetry. |
| `phys-fi-domain` | Physical domain attached to `fi-static-vlan-pool` for non-VMM workloads riding the FI uplinks. |
| `fi-aaep` | Carries BOTH the per-fabric VMM domain (so VM traffic via the VDS reaches ESXi behind FIs over `PC_FI_A`/`PC_FI_B`) AND `phys-fi-domain` (for static bare-metal VLANs). `infra_vlan: true` so ESXi VTEPs work for OpFlex. |
| `PC_FI_A`, `PC_FI_B` | Single-leaf port-channels (`type: pc`, not vpc) using `mac-pinning`. AAEP = `fi-aaep`. |
| `leaf-<X>-fi-intprof`, `leaf-<X>-prof` | Per-leaf interface and switch profiles binding eth1/6 (FI-A) and eth1/7 (FI-B). VMM port range trimmed from 1-48 to 8-48 to reserve eth1/1-7 for FI uplinks. |

NDO schema `data/nac-ndo/schema-aedce-ipv4.nac.yaml` is shared between lab and
prod -- there is one schema definition per environment because the EPG model
itself is identical; only the underlying APIC access policy differs. EPGs bind
to the per-fabric VMM domains (`APCG-VDS1`, `APCK-VDS1`) at the site-local
level inside the schema.

Cutover sequence for prod (when the prod Terraform root is in place):
`apic-vmware-prod/` apply (creates fi-aaep, PC_FI_A/B, static pool, VMM domain)
→ ESX admin moves uplinks onto `PC_FI_A` / `PC_FI_B` → `ndo/` apply (binds EPGs
to per-fabric VMM domains) → APIC dynamically allocates VLANs from
`vmm-vlan-pool` for VMM EPGs and pushes port-groups onto the existing per-
fabric VDS in vCenter.

## Repository Layout

```
aci-redesign/
├── README.md                       <-- you are here
├── IPv4_REDESIGN_OVERVIEW.md       full IPv4 design rationale + 215->39 BD consolidation
├── ACI_Redesign_Strategy.pptx      executive overview deck (built by build_redesign_pptx.py)
├── build_redesign_pptx.py          regenerates the .pptx from python-pptx
│
├── apic-vmware/                    APIC-direct Terraform root (access/fabric/MCP/VMM)
│   ├── main.tf                       4 module blocks: aci_aedcg, aci_mcp_aedcg,
│   │                                 aci_aedck, aci_mcp_aedck (+ moved {} blocks
│   │                                 to migrate state from old monolithic names)
│   ├── providers.tf                  default `aci` provider = AEDCG;
│   │                                 aliased `aci.aedck` = AEDCK
│   ├── variables.tf                  per-fabric: aedcg_apic_*, aedck_apic_*,
│   │                                 aedcg_mcp_key, aedck_mcp_key (all sensitive
│   │                                 secrets are sourced from TF_VAR_* env vars)
│   ├── terraform.tfvars              non-sensitive only: aedcg_apic_url/username,
│   │                                 aedck_apic_url/username (gitignored)
│   ├── terraform.tfvars.example      copy to terraform.tfvars and fill in
│   ├── Makefile                      `make plan|apply|apply-aedcg|apply-aedck|
│   │                                 destroy(-aedcg|-aedck)|auth-check|render(-aedcg|
│   │                                 -aedck)|clean`
│   ├── scripts/
│   │   ├── render-vmm-yaml.sh          `render-vmm-yaml.sh aedcg|aedck` renders
│   │   │                               templates/vmm-domain.nac.yaml.tftpl ->
│   │   │                               ../data/nac-aci-<fabric>-rendered/
│   │   ├── set-apic-password.sh        sourceable; hidden prompt -> TF_VAR_aedcg_apic_password
│   │   │                               and/or TF_VAR_aedck_apic_password (default = both)
│   │   ├── generate-mcp-key.sh         `generate-mcp-key.sh aedcg|aedck [length]`
│   │   │                               prints `export TF_VAR_<fabric>_mcp_key=...`
│   │   ├── auth-check.sh               POSTs aaaLogin.json to one or both fabrics
│   │   │                               (called by `make auth-check`)
│   │   └── diagnose-apic-auth.sh       `diagnose-apic-auth.sh aedcg|aedck` compares
│   │                                   env-var pwd vs typed pwd for one fabric
│   └── templates/
│       └── vmm-domain.nac.yaml.tftpl   ${vcenter_*} substitution targets (shared
│                                       across both fabrics in the lab)
│
├── ndo/                              NDO-managed Terraform root (tenant policy)
│   ├── main.tf                         calls netascode/nac-ndo/mso ~> 1.2.0;
│   │                                   manage_tenants=false (EUR pre-exists),
│   │                                   deploy_templates=false (manual UI deploy)
│   ├── providers.tf                    mso provider (platform=nd)
│   ├── variables.tf                    ndo_url/username/password/insecure/platform/domain
│   ├── terraform.tfvars                non-sensitive only; gitignored
│   ├── terraform.tfvars.example        copy + edit
│   ├── Makefile                        init / fmt / validate / plan / apply / destroy /
│   │                                   auth-check / clean
│   ├── scripts/
│   │   ├── auth-check.sh                 POST /login to NDO; supports nd + msc platforms
│   │   └── set-ndo-password.sh           sourceable; hidden prompt -> TF_VAR_ndo_password
│   └── README.md                       NDO-specific runbook
│
├── scripts/                          cross-cutting scripts (run after NDO apply)
│   ├── deploy_bindings.py              NDO REST helper: pushes EPG static port bindings
│   │                                   (vPC + regular ports). Auto-resolves template
│   │                                   from AEDCE-IPv4 schema. Adapted from N5K migration.
│   ├── bindings.example.json           starter input file for deploy_bindings.py
│   └── README.md                       script usage + JSON schema
│
├── data/
│   ├── nac-aci-shared/               cross-fabric APIC-direct policy
│   │   └── modules.nac.yaml            disables wrapper's aci_mcp submodule
│   │                                   (tenant content moved to data/nac-ndo/)
│   ├── nac-ndo/                      NDO-managed tenant policy (consumed by ndo/ root)
│   │   ├── tenant.nac.yaml             stub: tenant EUR is referenced, not created
│   │   └── schema-aedce-ipv4.nac.yaml  schema AEDCE-IPv4 with single template
│   │                                   Tenant_EUR_IPv4 -- 2 VRFs, 39 BDs, 2 ANPs,
│   │                                   39 EPGs w/ VMM bindings, 2 vzAny contracts
│   ├── _archive/                     deprecated YAMLs (reference only, not loaded)
│   │   └── tenant-epg-nac.nac.yaml.archived  old APIC-direct tenant model
│   ├── nac-aci-aedcg/                AEDCG-only access/fabric policies
│   │   └── access-policies.nac.yaml    VLAN pool 3501-3967, AAEP, leaf 152/153, VPC PG
│   ├── nac-aci-aedcg-rendered/       gitignored; rebuilt every `make plan` / `render-aedcg`
│   │   └── vmm-domain.nac.yaml         VMware VMM with vCenter creds substituted in
│   ├── nac-aci-aedck/                AEDCK-only access/fabric policies
│   │   └── access-policies.nac.yaml    same shape as AEDCG; leaf 119+191 (non-contiguous)
│   ├── nac-aci-aedck-rendered/       gitignored; rebuilt every `make plan` / `render-aedck`
│   │   └── vmm-domain.nac.yaml         per-fabric VMM (same vCenter today)
│   ├── blueprints/                   reference NAC blueprints (design references)
│   └── archive/                      historical NDO migration plans (not deployed)
│       ├── migration-phases/           7-phase NDO migration plan
│       └── alternate-approach/         alternate 4-phase NDO migration plan
│
└── docs/                             design/analysis docs (e.g., bd_mapping_analysis.txt)
```

## What Gets Created

Running `make apply` from `apic-vmware/` creates only the **APIC-direct** stack on BOTH fabrics: access/fabric policies, MCP Instance Policy, and the VMware VMM domain. The two tables below labelled "Access & Fabric Policies" describe what `apic-vmware/` lands on each APIC.

Running `make apply` from `ndo/` creates the **tenant policy** in NDO (schema `AEDCE-IPv4`, template `Tenant_EUR_IPv4`). Nothing reaches the APICs from the NDO Terraform until the operator clicks **Deploy to sites** in the NDO UI -- because `deploy_templates = false` is set in `ndo/main.tf`. See [NDO operator workflow](#ndo-operator-workflow) for the click-to-deploy sequence and [`scripts/deploy_bindings.py`](scripts/) for the static-port-binding push that follows.

### Access & Fabric Policies — AEDCG (`module.aci_aedcg` + `module.aci_mcp_aedcg`)

| ACI Object | File | Description |
|------------|------|-------------|
| VLAN Pool | `nac-aci-aedcg/access-policies.nac.yaml` | `vmm-vlan-pool` (dynamic, 3501-3967) |
| CDP Policy | `nac-aci-aedcg/access-policies.nac.yaml` | `cdp-enabled` -- declared under `access_policies.interface_policies.cdp_policies` (the netascode module reads CDP/LLDP/Port-Channel/Link-Level from `interface_policies.*`, not directly under `access_policies`) |
| LLDP Policy | `nac-aci-aedcg/access-policies.nac.yaml` | `lldp-enabled` (`admin_rx_state: true` + `admin_tx_state: true`; the module's keys are `admin_rx_state`/`admin_tx_state`, not `receive_state`/`transmit_state`) |
| Port Channel Policy | `nac-aci-aedcg/access-policies.nac.yaml` | `mac-pinning` (mode `mac-pin`; this is the LACP LAG / `lacpLagPol`. The module has no `lacp_policies` key -- PGs reference this via `port_channel_policy: <name>`) |
| Link Level Policy | `nac-aci-aedcg/access-policies.nac.yaml` | `10G` |
| AAEP | `nac-aci-aedcg/access-policies.nac.yaml` | `vmm-aaep` linked to VMM domain |
| VPC Interface Policy Group | `nac-aci-aedcg/access-policies.nac.yaml` | `vpc-vmm-hosts` |
| Leaf Interface Profile | `nac-aci-aedcg/access-policies.nac.yaml` | `leaf-152-153-intprof` (ports 1-48 for the lab simulator; `*-prod/` trims this to 8-48 to reserve eth1/6-7 for the FI uplinks) |
| Leaf Switch Profile | `nac-aci-aedcg/access-policies.nac.yaml` | `leaf-152-153-prof` (nodes 152-153, contiguous range) |
| VMware VMM Domain | `nac-aci-aedcg-rendered/vmm-domain.nac.yaml` | `APCG-VDS1` (read-write, adopts the existing per-fabric VDS in vCenter) |
| vCenter Controller | `nac-aci-aedcg-rendered/vmm-domain.nac.yaml` | `vcenter01` with credential policy |
| Virtual Distributed Switch | `nac-aci-aedcg-rendered/vmm-domain.nac.yaml` | Adopted from vCenter via `dvs_version: unmanaged` (APIC accepts whatever version vCenter has; `unmanaged` is the only safe value across the module's allowed set when vCenter is 7.x/8.x) |
| VDS Uplinks | `nac-aci-aedcg-rendered/vmm-domain.nac.yaml` | inherited from the existing VDS during adoption |
| MCP Instance Policy | `apic-vmware/main.tf` (`module.aci_mcp_aedcg`) | `default` w/ key from `TF_VAR_aedcg_mcp_key` |

### Access & Fabric Policies — AEDCK (`module.aci_aedck` + `module.aci_mcp_aedck`)

Same object shape as AEDCG but read from `nac-aci-aedck/` and pushed via the aliased `aci.aedck` provider. AEDCK leaf nodes are 119 and 191 (non-contiguous, so the switch profile uses two single-node `node_blocks` rather than a `from`/`to` range). Re-check these IDs against the live fabric before any production apply.

| ACI Object | File | Description |
|------------|------|-------------|
| VLAN Pool / CDP / LLDP / Port-Channel / LinkLevel / AAEP / VPC PG | `nac-aci-aedck/access-policies.nac.yaml` | identical names + values to AEDCG (names are scoped per-APIC, so this is safe). Same `access_policies.interface_policies.*` nesting + same `mac-pin` LACP mode + same `admin_rx_state`/`admin_tx_state` LLDP keys. |
| Leaf Interface Profile | `nac-aci-aedck/access-policies.nac.yaml` | `leaf-119-191-intprof` (ports 1-48 for the lab simulator; `*-prod/` trims this to 8-48 to reserve eth1/6-7 for FI uplinks) |
| Leaf Switch Profile | `nac-aci-aedck/access-policies.nac.yaml` | `leaf-119-191-prof` (nodes 119 + 191, two single-node node_blocks) |
| VMware VMM Domain / vCenter / VDS / Uplinks | `nac-aci-aedck-rendered/vmm-domain.nac.yaml` | rendered from same template; the VMM domain name is fabric-specific (`APCK-VDS1`) so it adopts the per-fabric VDS that already exists in vCenter for AEDCK |
| MCP Instance Policy | `apic-vmware/main.tf` (`module.aci_mcp_aedck`) | `default` w/ key from `TF_VAR_aedck_mcp_key` |

### Tenant EUR -- VRF-EUR (Internal IPv4) -- NDO-managed

Tenant content is no longer pushed by `apic-vmware/`. The `ndo/` root creates
schema `AEDCE-IPv4` with a single template `Tenant_EUR_IPv4`; the operator
clicks **Deploy to sites** in the NDO UI to land it on AEDCG and AEDCK. See
[NDO operator workflow](#ndo-operator-workflow).

| ACI Object | NDO source | Description |
|------------|------------|-------------|
| Filter (cross-schema ref) | `data/nac-ndo/schema-aedce-ipv4.nac.yaml` | `Any` filter is referenced from `AEDCE / UpgradeTemplate1` (NDO requires unique object names per tenant) |
| Contract | `data/nac-ndo/schema-aedce-ipv4.nac.yaml` | `Any_VRF-EUR` (scope: context, vzAny permit-all) |
| VRF | `data/nac-ndo/schema-aedce-ipv4.nac.yaml` | `VRF-EUR` -- vzAny provider + consumer of `Any_VRF-EUR` |
| Bridge Domains | `data/nac-ndo/schema-aedce-ipv4.nac.yaml` | 36 BDs with descriptive names (BD-AD, BD-APP-SVR, BD-CFG-MGMT, etc.) -- multi-subnet from legacy consolidation |
| EPGs | `data/nac-ndo/schema-aedce-ipv4.nac.yaml` | 36 EPGs under `AppProf-NetCentric` bound to `APCG-VDS1` on AEDCG and `APCK-VDS1` on AEDCK (dynamic VLAN allocated from `vmm-vlan-pool` 3501-3967) |
| Static port bindings | pushed by `scripts/deploy_bindings.py` after the NDO Deploy | per-EPG `staticPorts[]`; not modeled in nac-ndo YAML |
| ESG | (deferred) | nac-ndo `~> 1.2.0` does not yet expose ESG selectors. Will be added once the module catches up. |

### Tenant EUR -- VRF-DMZ -- NDO-managed

| ACI Object | NDO source | Description |
|------------|------------|-------------|
| Contract | `data/nac-ndo/schema-aedce-ipv4.nac.yaml` | `Any_VRF-DMZ` (scope: context, vzAny permit-all) |
| VRF | `data/nac-ndo/schema-aedce-ipv4.nac.yaml` | `VRF-DMZ` -- vzAny provider + consumer of `Any_VRF-DMZ` |
| Bridge Domains | `data/nac-ndo/schema-aedce-ipv4.nac.yaml` | 3 BDs: `BD-D64-PROXY`, `BD-FWEB-PROXY`, `BD-RWEB-PROXY` |
| EPGs | `data/nac-ndo/schema-aedce-ipv4.nac.yaml` | 3 EPGs under `AppProf-DMZ` bound to `APCG-VDS1` on AEDCG and `APCK-VDS1` on AEDCK (dynamic VLAN allocated from `vmm-vlan-pool` 3501-3967) |
| Static port bindings | pushed by `scripts/deploy_bindings.py` after the NDO Deploy | per-EPG `staticPorts[]` |
| ESG | (deferred) | same reason as VRF-EUR ESG row above |

## apic-vmware/

The single Terraform root. Deploys directly to APIC (no NDO), to BOTH AEDCG and AEDCK simultaneously via provider aliases. Uses the `netascode/nac-aci` module (v0.7.0) plus a standalone `aci_mcp` module for each fabric's MCP Instance Policy.

| File | Purpose |
|------|---------|
| `main.tf` | 4 module blocks: `aci_aedcg`, `aci_mcp_aedcg`, `aci_aedck`, `aci_mcp_aedck`. Two `moved {}` blocks rename the previous monolithic `module.aci` / `module.aci_mcp` to the new AEDCG-suffixed names (in-place state move; no destroy/recreate) |
| `providers.tf` | default `provider "aci"` = AEDCG (`var.aedcg_apic_*`); aliased `provider "aci" { alias = "aedck" }` = AEDCK (`var.aedck_apic_*`). Modules opt into AEDCK with `providers = { aci = aci.aedck }` |
| `variables.tf` | per-fabric: `aedcg_apic_url/username/password/insecure`, `aedcg_mcp_key`, and the same set with `aedck_` prefix. Validates each MCP key length ≥ 8 |
| `terraform.tfvars` | non-sensitive values only (`aedcg_apic_url/username`, `aedck_apic_url/username`). gitignored. **Do not** put any password or MCP key here -- file values beat env vars in Terraform precedence |
| `terraform.tfvars.example` | safe-to-commit template; copy to `terraform.tfvars` once and edit |
| `Makefile` | wraps `terraform`. Always renders BOTH fabrics' VMM YAML before plan/apply. Per-fabric targets: `apply-aedcg`, `apply-aedck`, `destroy-aedcg`, `destroy-aedck`, `render-aedcg`, `render-aedck`, `auth-check FABRIC=...` |
| `scripts/` | `render-vmm-yaml.sh <fabric>`, `set-apic-password.sh [aedcg|aedck]`, `generate-mcp-key.sh <fabric> [length]`, `auth-check.sh [aedcg|aedck|both]`, `diagnose-apic-auth.sh <fabric>`. See [Quick Start](#quick-start) cheat sheet |
| `templates/vmm-domain.nac.yaml.tftpl` | python `string.Template` syntax (`${vcenter_hostname_ip}` etc.) -- substituted by `render-vmm-yaml.sh` for each fabric, never read by Terraform directly |

### Before you apply

1. **Set the four non-sensitive APIC fields** in `terraform.tfvars` (one-time): `aedcg_apic_url`, `aedcg_apic_username`, `aedck_apic_url`, `aedck_apic_username`. These are tracked in your local copy of the file (which is gitignored).
2. **Export the secrets** in your shell every time you open a new terminal:

   ```bash
   source scripts/set-apic-password.sh                      # both fabrics, same lab pw
   eval "$(./scripts/generate-mcp-key.sh aedcg)"            # TF_VAR_aedcg_mcp_key
   eval "$(./scripts/generate-mcp-key.sh aedck)"            # TF_VAR_aedck_mcp_key
   export TF_VAR_vcenter_hostname_ip='198.18.134.80'
   export TF_VAR_vcenter_datacenter='Datacenter'
   export TF_VAR_vcenter_username='administrator@vsphere.local'
   export TF_VAR_vcenter_password='<vCenter password>'      # single quotes!
   export TF_VAR_vcenter_dvs_version='unmanaged'            # see env-var table for why
   ```
3. **Sanity-check APIC creds before going further.** `make auth-check` POSTs `/api/aaaLogin.json` to BOTH fabrics; HTTP 200 on each = ready, anything else = stop and read the [Troubleshooting](#troubleshooting) entry for that code. To scope to one fabric, run `make auth-check FABRIC=aedcg` or `make auth-check FABRIC=aedck`.
4. **Verify leaf node IDs.** `data/nac-aci-aedcg/access-policies.nac.yaml` is configured for nodes 152 and 153; `data/nac-aci-aedck/access-policies.nac.yaml` for nodes 119 and 191. These reflect the current lab cabling and are likely to change — confirm against the live fabric before any production apply.
5. **Initialize Terraform** if the `.terraform/` directory is missing: `make init`.

There are deliberately no `CHANGE_ME` placeholders in tracked YAML anymore. The vCenter values that used to be `CHANGE_ME` strings now flow in from `TF_VAR_vcenter_*` env vars and are substituted by `render-vmm-yaml.sh` into the gitignored `data/nac-aci-<fabric>-rendered/vmm-domain.nac.yaml` (one per fabric).

### Usage

```bash
cd aci-redesign/apic-vmware
make plan            # renders BOTH fabrics' VMM YAML, runs terraform plan -> plan.tfplan
make apply           # applies plan.tfplan (both fabrics)
make apply-aedcg     # apply only AEDCG  (-target=module.aci_aedcg + module.aci_mcp_aedcg)
make apply-aedck     # apply only AEDCK
make destroy-aedcg   # tear down AEDCG only (lab cleanup)
```

`make plan` / `make apply` always re-run `render-vmm-yaml.sh aedcg` and `render-vmm-yaml.sh aedck` first, so rotating any credential is just `export TF_VAR_<name>='...' && make plan`. There is no separate "render then plan" workflow you have to remember.

## data/nac-aci-shared/

YAML that should be identical on every fabric. Consumed by every `module "aci_*"` call in `main.tf` via `yaml_directories`. Tenant content moved to `data/nac-ndo/`; only the wrapper-modules toggle remains here.

| File | Section | Purpose |
|------|---------|---------|
| `modules.nac.yaml` | `modules` | disables the wrapper's internal `aci_mcp` submodule so we can manage MCP standalone with a sensitive key |

## data/nac-ndo/

NDO-managed tenant policy. Consumed by the sister `ndo/` Terraform root via the `netascode/nac-ndo/mso` module. Not loaded by `apic-vmware/`.

| File | Section | Purpose |
|------|---------|---------|
| `tenant.nac.yaml` | `ndo.tenants` (stub) | tenant `EUR` already exists in NDO from the IPv6 redesign; the `ndo/` root references it (`manage_tenants=false`) without owning its lifecycle |
| `schema-aedce-ipv4.nac.yaml` | `ndo.schemas[AEDCE-IPv4]` | one template (`Tenant_EUR_IPv4`) with all 39 BDs, 39 EPGs, 2 VRFs (vzAny), 2 contracts (filter cross-ref to `AEDCE/UpgradeTemplate1`), 2 ANPs, EPG-to-VMM-domain bindings on AEDCG + AEDCK |

## data/nac-aci-aedcg/

AEDCG-specific access and fabric policies. Anything in here only lands on AEDCG.

| File | Section | Purpose |
|------|---------|---------|
| `access-policies.nac.yaml` | `apic.access_policies` | VLAN pool (3501-3967), CDP/LLDP/LACP/PortChannel/Link-Level policies, AAEP, VPC policy group, leaf 152-153 interface + switch profiles |

## data/nac-aci-aedck/

AEDCK-specific access and fabric policies. Same shape as AEDCG; pushed via the aliased `aci.aedck` provider. Object names (VLAN pool, AAEP, etc.) are deliberately identical to AEDCG so the shared tenant content in `nac-aci-shared/` works on both APICs unchanged — these names are scoped per-APIC, so reusing them is safe.

| File | Section | Purpose |
|------|---------|---------|
| `access-policies.nac.yaml` | `apic.access_policies` | same shape as AEDCG. Leaf nodes 119 + 191 (non-contiguous → two single-node `node_blocks`). |

## data/nac-aci-{aedcg,aedck}-rendered/ (gitignored)

Build artifacts, one directory per fabric, regenerated on every `make plan` / `make apply` (or scoped `make render-aedcg` / `make render-aedck`). Each holds `vmm-domain.nac.yaml` after `render-vmm-yaml.sh <fabric>` has substituted the `${vcenter_*}` values from `TF_VAR_vcenter_*`. Mode 0600. Never commit anything from these directories.

## data/blueprints/

NAC YAML reference blueprints for the ACI redesign. These use the `apic:` root key (nac-aci format, direct APIC). They document design patterns including tenant config, VRFs, BDs, EPGs, contracts, ESGs, FTDv firewall integration, DHCP relay, IP SLA, service graphs, and prefix leaking.

| File | Description |
|------|-------------|
| `blueprint-1.nac.yaml` | Base design -- tenant, VRFs, BDs, EPGs, contracts, FTDv, service graph, DHCP relay |
| `blueprint-2.nac.yaml` through `blueprint-9.nac.yaml` | Incremental design variations |
| `blueprint-10.nac.yaml` | Full design with all features |
| `blueprint-rcc-vmm-nac.nac.yaml` | EUR tenant, AppProf-RCC, EPG-NAC on VMM domain (template) |

## data/archive/

Archived NDO-format NAC configs (`ndo:` root key) used during the original migration planning. These are **reference only** and not actively deployed.

### migration-phases/

7-phase migration plan for transitioning to the new ACI design via NDO:

| Phase | File | Description |
|-------|------|-------------|
| 1 | `1-base-build.nac.yaml` | Sites (AEDCK/AEDCG), tenant EUR, schema AEDCE, VRFs, BDs, EPGs, subnets |
| 2 | `2-add-single-esg-for-all-epgs.nac.yaml` | Add ESG grouping all EPGs |
| 3 | `3-add-app-centric-migration.nac.yaml` | App-centric contract migration |
| 4 | `4-add-tighter-contracts.nac.yaml` | Tighten contract scope |
| 5 | `5-add-prefix-leaking-to-shared-l3out.nac.yaml` | Prefix leaking to shared L3Out |
| 6 | `6-add-ftdv.nac.yaml` | FTDv firewall integration |
| 7 | `7-insert-service-graph.nac.yaml` | Service graph insertion |

### alternate-approach/

4-phase alternate migration approach (phases 1-4 only).

## Related Workspace Folders

| Workspace Folder | Purpose |
|------------------|---------|
| LAB - IPv6 RCC (ndo-terraform) | IPv6 RCC infrastructure via direct Terraform HCL on NDO |
| LAB - IPv4 NAC (ndo_terraform) | Ansible/Python tools for fabric policies and static port bindings |
| LAB - IPv4 NAC Terraform (ndo_terraform_nac) | Full Terraform NAC project -- all NDO objects for IPv4 (schema_AEDCE.nac.yaml) |
| LAB - N5K Migration & Leaf Replacement | N5K migration and ACI leaf replacement toolkit |

# End-to-End Lab Deployment Runbook

**This is THE canonical runbook for deploying the lab from scratch.** It covers
both `terraform-esg` and the sibling `ndo-terraform-nac-prod` repo, in the
correct order, with all the manual NDO-UI deploy steps in between.

For per-stack details (env vars, gotchas, error catalog), each Terraform root
has its own `README.md` (reference) and `README_LAB.md` (lab daily-driver).
This file is the orchestration layer that ties them together.

> **IPs and credentials in this document are placeholders / lab values.** Lab
> APIC and NDO IPs rotate when dCloud rebuilds; production values live in
> per-stack `terraform.tfvars` files (gitignored) and GitLab masked CI
> variables. Always cross-check the current values before applying.

## TL;DR for someone with no prior knowledge

You'll touch **two git repos** and **a GitLab UI**:

```text
~/DC/ACI/ndo-terraform-nac-prod/    # sibling repo — Phase 1 only
~/DC/ACI/terraform-esg/             # this repo — Phases 3, 4, 5, 6
GitLab UI                            # Phase 2 (manual NDO template deploys)
                                     # and triggering apply jobs
```

For each Terraform root you'll work in, the **first time only** do this:

1. Clone the repo and `cd` into the root (e.g. `~/DC/ACI/ndo-terraform-nac-prod/` for Phase 1, `aci-redesign/ndo/` for Phase 4, etc.).
2. Decide between **laptop runs** (this runbook) or **CI runs** (push to `main`, let the GitLab pipeline drive it). Pick one per session.
3. **Laptop runs only**: drop a gitignored `local_override.tf` containing `terraform { backend "local" {} }` so Terraform uses a local state file instead of trying to talk to GitLab. This is gitignored at the repo root via the `*_override.tf` rule and never reaches CI:

   ```bash
   cat > local_override.tf <<'EOF'
   terraform { backend "local" {} }
   EOF
   ```
4. Set per-project credentials. Per-stack: `.env` for `nac-prod` (Phase 1); `terraform.tfvars` + `TF_VAR_ndo_password` for `aci-redesign/ndo/` (Phase 4); `lab.tfvars` + `terraform.tfvars` for `ndo-terraform-ipv6/` (Phase 5). Each phase below shows the exact commands.
5. `terraform init`, then `terraform plan`, then `terraform apply` — exactly as Phase N below shows.

After every Terraform `apply` against an NDO stack, **the changes are in NDO but NOT yet on the APICs**. Each NDO stack ends with a manual NDO-UI **Deploy to sites** step. The phases below show the order and target sites for each.

If you'd rather drive everything through CI: skip the `local_override.tf` step, set the per-project GitLab CI/CD variables (see [`README.md`](README.md) → "Required CI/CD variables"), commit + push, and GitLab runs validate + plan automatically. Apply is **manual** (button in the UI) for every stack except `nac-prod`, where it auto-runs on `main` (safe because `deploy_templates = false`). The state backend uses `${CI_JOB_TOKEN}` — no PAT to provision, no expiry to manage. See [`README.md`](README.md) → "CI/CD pipeline".

---

## Documentation map

```
~/DC/ACI/
├── ndo-terraform-nac-prod/                    [Phase 1 — separate repo]
│   ├── README.md                              prod NDO-NAC reference
│   └── README_LAB.md                          lab toggle walkthrough
│
└── terraform-esg/
    ├── README.md                              repo intro + GitLab CI/runner setup
    ├── README_LAB.md                          THIS FILE — end-to-end runbook
    ├── PROJECT_MAP.md                         server/path/CI cross-reference
    ├── PROJECTS_LISTING.md                    every Mac project + remotes
    │
    ├── aci-redesign/
    │   ├── README.md                          directory pointer + index
    │   ├── DESIGN.md                          2-VRF redesign rationale, BD/EPG model
    │   │
    │   ├── apic-vmware/                       [Phase 3 — APIC fabric/VMM, lab]
    │   │   ├── README.md                      reference (env vars, errors)
    │   │   └── README_LAB.md                  lab daily-driver
    │   │
    │   ├── apic-vmware-prod/                  [Phase 3 sibling — APIC, prod]
    │   │   └── README.md
    │   │
    │   ├── ndo/                               [Phase 4 — IPv4 redesign tenant tree]
    │   │   ├── README.md                      reference (cutover, schema)
    │   │   └── README_LAB.md                  lab daily-driver
    │   │
    │   ├── scripts/                           [Phase 6 — bindings push tools]
    │   │   └── README.md                      CLI reference (dump_bindings,
    │   │                                       deploy_bindings, generate_fi_bindings)
    │   │
    │   └── data/                              shared NAC YAML inputs
    │       ├── _archive/README.md             archived blueprint note
    │       └── nac-aci-shared/README.md       data tier note
    │
    ├── ndo-terraform-ipv6/                    [Phase 5 — IPv6 RCC layer]
    │   ├── README.md                          reference + GitLab CI
    │   └── README_LAB.md                      lab daily-driver
    │
    └── docs/README.md                         architecture docs index
```

When in doubt, **start here** and follow the phases below. Each phase points
at the per-stack README for details.

---

## Phase summary

| # | What | Where | Time | Manual? |
|---|------|-------|------|---------|
| 1 | Build foundational NDO state (tenant `EUR`, schema `AEDCE`, 5 prod templates) | `~/DC/ACI/ndo-terraform-nac-prod/` | ~10 min plan/apply | Terraform |
| 2 | Deploy 5 templates to AEDCG/AEDCK (in strict order) | NDO UI | ~15 min total | **Manual UI** |
| 3 | APIC fabric/access policies, MCP, VMware VMM domains | `terraform-esg/aci-redesign/apic-vmware/` | ~5 min apply | Terraform (both fabrics in one root) |
| 4 | IPv4 redesign tenant tree (schema `AEDCE-IPv4`, template `Tenant_EUR_IPv4`) | `terraform-esg/aci-redesign/ndo/` | ~5 min apply + UI deploy | Terraform + manual UI |
| 5 *(optional)* | IPv6 RCC layer (adds `AppProf-RCC` to existing `L2_Stretched`) | `terraform-esg/ndo-terraform-ipv6/` | ~30 min apply at `-parallelism=3` | Terraform + manual UI re-deploy |
| 6 | Static port bindings (post-deploy push not modeled in NAC YAML) | `terraform-esg/aci-redesign/scripts/` | ~2 min | Python + manual UI re-deploy |
| 7 | Verify on APICs and vCenter | APIC GUI + vCenter | as needed | Manual |

Phase 5 is optional **only** if you take Phase 6 Path B (`generate_fi_bindings.py`).
If you take Phase 6 Path A (`dump_bindings.py`), Phase 5 is a hard prerequisite.

---

## Phase 1 — Foundational NDO build (`ndo-terraform-nac-prod`)

This repo creates **tenant `EUR`**, **schema `AEDCE`** with five templates
(`VRF_Template`, `L2_Stretched`, `L2_Non-Stretched`, `G-Specific_Only`,
`K-Specific_Only`), 11 prod VRFs, 266 BDs, 265 EPGs, 13 L3Outs, and 812 VPC
static-port bindings. Phase 4 in `terraform-esg/aci-redesign/ndo/` cross-
references `AEDCE / VRF_Template / Any` (the filter), so this phase has to
land first.

```bash
cd ~/DC/ACI/ndo-terraform-nac-prod

# 1.1 Pick lab credentials in .env (gitignored). Both lab and prod blocks
#     ship in the file; uncomment the lab one:
#     export MSO_DOMAIN="DefaultAuth"
#     export MSO_URL="https://198.18.133.100"
#     export MSO_USERNAME="admin"
#     export MSO_PASSWORD="<lab password>"
$EDITOR .env
source .env

# 1.2 Verify NDO is reachable (HTTP 200 / 302 = healthy, 000 = down/wrong URL).
curl -k -m 5 -o /dev/null -w 'http=%{http_code}\n' "$MSO_URL"

# 1.3 Confirm lab APIC URLs are uncommented (and prod URLs commented) in the
#     two `sites:` blocks of data/ndo/ndo.nac.yaml.
grep -E '^\s+- https://' data/ndo/ndo.nac.yaml

# 1.4 Init (first time only or after module/provider bumps), plan, apply.
terraform init
terraform plan
terraform apply
```

After `apply`: schema content **exists in NDO** but the templates are **not
deployed to the APICs yet** (`deploy_templates = false`). Move to Phase 2.

Details: `~/DC/ACI/ndo-terraform-nac-prod/README.md` (architecture, troubleshooting)
and `README_LAB.md` (lab toggle).

---

## Phase 2 — Manual NDO-UI deploy of `AEDCE` templates

Strict order. Cross-template VRF dependencies will break the deploy if you skip
ahead — error message is "VRF EUR-X must be deployed on Fabric AEDCK before
BD type … can be deployed".

NDO UI → **Application Management → Schemas → AEDCE** → for each template,
click **Deploy to sites** in this order, **waiting for green** between steps:

| # | Template | Sites |
|---|----------|-------|
| 2.1 | `VRF_Template` | AEDCG, then AEDCK |
| 2.2 | `L2_Stretched` | AEDCG, then AEDCK |
| 2.3 | `L2_Non-Stretched` | AEDCG, then AEDCK |
| 2.4 | `G-Specific_Only` | AEDCG only |
| 2.5 | `K-Specific_Only` | AEDCK only |

After Phase 2: tenant `EUR`, all 11 VRFs (incl. `EUR-E`), schema `AEDCE` with
`Any` filter under `VRF_Template`, all 266 BDs and 265 EPGs are live on AEDCG
and AEDCK.

---

## Phase 3 — APIC-direct fabric & VMM (`aci-redesign/apic-vmware/`)

Builds access policies, MCP Instance Policies (per fabric, with per-fabric
keys), and the VMware VMM domains `APCG-VDS1` (on AEDCG) and `APCK-VDS1`
(on AEDCK) that Phase 4's EPGs will bind to. Independent of Phase 2 — could
technically run in parallel — but in practice do it after.

```bash
cd ~/DC/ACI/terraform-esg/aci-redesign/apic-vmware

# 3.1 Non-sensitive bits in terraform.tfvars (gitignored — copy from the example)
test -f terraform.tfvars || cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # set aedcg_apic_url/username, aedck_apic_url/username

# 3.2 Sensitive env vars (per shell)
source scripts/set-apic-password.sh                 # both fabrics, same lab password
eval "$(./scripts/generate-mcp-key.sh aedcg)"        # TF_VAR_aedcg_mcp_key
eval "$(./scripts/generate-mcp-key.sh aedck)"        # TF_VAR_aedck_mcp_key
export TF_VAR_vcenter_hostname_ip='198.18.134.80'
export TF_VAR_vcenter_datacenter='Datacenter'
export TF_VAR_vcenter_username='administrator'
export TF_VAR_vcenter_password='C1sco12345!'         # SINGLE quotes — ! triggers history expansion
export TF_VAR_vcenter_dvs_version='unmanaged'        # 7.x/8.x rejected by validator

# 3.3 Sanity check, plan, apply
make auth-check
make plan
make apply
```

After Phase 3: `APCG-VDS1` exists on AEDCG APIC, `APCK-VDS1` exists on AEDCK
APIC, both registered against vCenter.

Details: `aci-redesign/apic-vmware/README_LAB.md` (lab daily-driver),
`README.md` (env-var table, MCP-key rationale, error catalog).

---

## Phase 4 — IPv4 redesign tenant tree (`aci-redesign/ndo/`)

This is where the cross-schema reference to `AEDCE/VRF_Template/Any` (built
in Phase 1, deployed in Phase 2) actually resolves. Schema `AEDCE-IPv4`
contains a **single template** `Tenant_EUR_IPv4` (2 VRFs, 39 BDs, 39 EPGs,
2 ANPs, 2 contracts; no static ports — those come in Phase 6).

```bash
cd ~/DC/ACI/terraform-esg/aci-redesign/ndo

# 4.1 Non-sensitive bits
test -f terraform.tfvars || cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # ndo_url, ndo_username, ndo_platform, ndo_domain

# 4.2 NDO password (per shell)
source scripts/set-ndo-password.sh

# 4.3 Sanity check, init, plan, apply
make auth-check
make init    # only first time
make plan    # expect: 1 schema (AEDCE-IPv4), 1 template (Tenant_EUR_IPv4),
             #         2 VRFs, 39 BDs, 2 ANPs, 39 EPGs, 2 contracts.
             # NO mso_tenant create (manage_tenants=false; EUR is from Phase 1).
make apply
```

Then NDO UI → **Application Management → Schemas → AEDCE-IPv4 →
`Tenant_EUR_IPv4` → Deploy to sites** → AEDCG and AEDCK. **One template here**,
not three (any older docs that say `Tenant_Policy / Stretched_BDs /
App_Profiles` reflect an abandoned design).

After Phase 4: 2 VRFs (`VRF-EUR`, `VRF-DMZ`), 39 BDs, 39 EPGs are live on
AEDCG and AEDCK; each EPG is bound to the per-fabric VMM domain from Phase 3
(`APCG-VDS1` on AEDCG, `APCK-VDS1` on AEDCK), so 39 port-groups should now
exist on each VDS in vCenter.

Details: `aci-redesign/ndo/README_LAB.md` (lab daily-driver), `README.md`
(schema layout, deploy-to-sites rationale).

---

## Phase 5 *(optional)* — IPv6 RCC layer (`ndo-terraform-ipv6/`)

Only do this phase if you need the IPv6 RCC EPGs (`EPG-NAC`, `EPG-CFG-MGMT`,
`EPG-RCC-DNS`, … 39 in total) under a new ANP `AppProf-RCC` inside the
existing `L2_Stretched` template, **and/or** you intend to use Phase 6
Path A (`dump_bindings.py`) which reads from `AEDCE/AppProf-RCC` to seed
IPv4 bindings.

```bash
cd ~/DC/ACI/terraform-esg/ndo-terraform-ipv6

# 5.1 local_override.tf must exist (gitignored, forces local state). If
#     you've already done the laptop-bootstrap step from "TL;DR for someone
#     with no prior knowledge" above, this is already in place.
ls local_override.tf || cat > local_override.tf <<'EOF'
terraform {
  backend "local" {}
}
EOF

# 5.2 Credentials (env vars, NOT in tfvars — see ndo-terraform-ipv6/README_LAB.md
#     for why mixing layers causes silent overrides).
export TF_VAR_ndo_url='https://198.18.133.100'
export TF_VAR_ndo_username='admin'
read -rs TF_VAR_ndo_password && export TF_VAR_ndo_password

# 5.3 Init + plan + apply. Both flags matter — do not change them.
terraform init
terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 -out=plan.tfplan
terraform apply plan.tfplan
```

Then NDO UI → schema `AEDCE` → template `L2_Stretched` → **Deploy to sites**
again (since this Terraform run added `AppProf-RCC` and 39 IPv6 EPGs into
`L2_Stretched`).

The "Deferred — re-enable after bindings" stages 6a/6b/6c documented in
`ndo-terraform-ipv6/README_LAB.md` happen **after** our Phase 6, not before.

Details: `ndo-terraform-ipv6/README_LAB.md` (lab daily-driver), `README.md`
(NDO bootstrap on a fresh dCloud ND 4.1, GitLab CI).

---

## Phase 6 — Static port bindings (`aci-redesign/scripts/`)

The NAC YAML doesn't model `staticPorts[]`, so EPGs created in Phase 4 land
on the APICs with no static-port bindings. Phase 6 PATCHes them in via the
NDO REST API. Pick **one** path:

### Path A — dump from IPv6 RCC (lab default; requires Phase 5)

```bash
cd ~/DC/ACI/terraform-esg/aci-redesign/scripts
export NDO_HOST=198.18.133.100
export NDO_USER=admin

# Read AEDCE/AppProf-RCC, write a JSON for AEDCE-IPv4.
./dump_bindings.py --leaves 152,153,119,191 \
                   --output current_bindings.json --dry-run     # preview
./dump_bindings.py --leaves 152,153,119,191 \
                   --output current_bindings.json               # write

# Review current_bindings.json, decide your VLAN strategy (default strips VLAN
# but deploy_bindings.py requires one — see scripts/README.md).

./deploy_bindings.py current_bindings.json --no-vault --dry-run  # preview
./deploy_bindings.py current_bindings.json --no-vault            # commit
```

### Path B — generate from FI topology (prod default; Phase 5 not required)

```bash
cd ~/DC/ACI/terraform-esg/aci-redesign/scripts

# Lab "Approach 1" — physical-only EPGs (EPG-LB, EPG-LMR, EPG-VHOST-MGMT × 4 PCs).
./generate_fi_bindings.py --physical-only \
    --output           fi_bindings.json \
    --output-manifest  fi_epg_manifest.json

# Prod "Approach 2" — every EPG × 4 PCs, with VLAN map. Required when ESXi
# hosts ride UCS FIs (FI breaks dynamic VMM VLAN learning).
./generate_fi_bindings.py \
    --vlan-map         fi_vlan_map.json \
    --output           fi_bindings.json \
    --output-manifest  fi_epg_manifest.json

./deploy_bindings.py fi_bindings.json --no-vault --dry-run
./deploy_bindings.py fi_bindings.json --no-vault
```

Whichever path: finish in **NDO UI → schema AEDCE-IPv4 → Tenant_EUR_IPv4 →
Deploy to sites** (re-deploy) so the new `staticPorts[]` push to APIC.

Details: `aci-redesign/scripts/README.md` (CLI reference, vault flow, VLAN
strategy rationale).

---

## Phase 7 — Verify

| Where | Check |
|---|---|
| AEDCG APIC GUI | `Tenants → EUR → Application Profiles → AppProf-AppCentric / AppProf-DMZ` shows 39 EPGs (36 + 3) |
| AEDCK APIC GUI | Same — both ANPs, 39 EPGs |
| Each EPG's "Domains" tab | Per-fabric VMM domain (`APCG-VDS1` or `APCK-VDS1`) bound, `Resolution Immediacy = Immediate` |
| Each EPG's "Static Ports" tab | Phase 6 bindings present with the right leaf/port/VLAN |
| vCenter | 39 port-groups under each of `APCG-VDS1` / `APCK-VDS1` |
| Phase 5 Phase-Two outcome (if done) | `AppProf-RCC` ANP visible in `Tenants → EUR → Application Profiles` with 39 IPv6 EPGs |

If anything is missing on the APIC: re-check that you clicked **Deploy to
sites** after the relevant Terraform `apply`.

---

## Lab credentials and connection points

| Component | Lab value (today; rotates) | Where to set it |
|-----------|----------------------------|-----------------|
| NDO | `https://198.18.133.100`, `admin`, dCloud password | `ndo-terraform-nac-prod/.env`, `aci-redesign/ndo/terraform.tfvars`, `ndo-terraform-ipv6/terraform.tfvars`, plus `TF_VAR_ndo_password` env var per shell |
| AEDCG APIC | `https://198.18.134.252` | `aci-redesign/apic-vmware/terraform.tfvars` + `TF_VAR_aedcg_apic_password` |
| AEDCK APIC | `https://198.18.134.253` | `aci-redesign/apic-vmware/terraform.tfvars` + `TF_VAR_aedck_apic_password` |
| vCenter | `198.18.134.80`, `administrator`, `C1sco12345!` | `TF_VAR_vcenter_*` env vars only |
| MCP key (per fabric) | generate fresh per session, ≥8 chars mixed | `eval "$(./scripts/generate-mcp-key.sh aedcg)"` etc. |

Lab IPs change. If `auth-check` or `terraform plan` returns timeouts or 401s,
the first thing to verify is whether the IPs in the tfvars files / `.env`
files still match what dCloud actually has today.

---

## State backend (lab vs CI)

Every Terraform root in this repo (and the sibling `nac-prod` repo) declares `backend "http" {}` in `main.tf` so CI uses the GitLab HTTP backend. Laptop users opt out by dropping a gitignored `local_override.tf`.

| | Lab (your laptop) | CI / production |
|---|-------------------|-----------------|
| Backend | `local_override.tf` overrides to local file (`terraform.tfstate` per dir) | GitLab HTTP backend at `${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/<state-name>` |
| Backend auth | none (file on disk) | `gitlab-ci-token` / `${CI_JOB_TOKEN}` — pinned in each per-project `*-vars` anchor; no PAT, no expiry |
| Trigger | manual `terraform plan/apply` | push / MR drives `.gitlab-ci.yml` jobs (see [`README.md`](README.md) → CI/CD pipeline) |
| Credentials | `terraform.tfvars` + `TF_VAR_*` env vars (per stack) | Masked GitLab CI/CD variables (per stack) |

Each project's `README_LAB.md` Step 1 walks through creating the `local_override.tf`; the file is one line:

```bash
echo 'terraform { backend "local" {} }' > local_override.tf
```

The repo-root `.gitignore` excludes `*_override.tf`, so the override file never reaches CI. CI runners do a fresh clone, never see the override, and use the HTTP backend with `${CI_JOB_TOKEN}`.

If you swap between laptop and CI mid-session, you'll get state-lineage mismatch errors. Pick one mode and stay with it for the duration of a change. The recovery path (when state slots get out of sync because of a wipe or rebuild) is `terraform state pull` from the working backend, then `terraform init -migrate-state -force-copy` to push that state into the empty slot — see each project's `README.md` → "State backend".

---

## Troubleshooting links

- **`HTTP remote state endpoint requires auth`** in any directory →
  `ndo-terraform-ipv6/README_LAB.md` troubleshooting. Same fix everywhere.
- **`Post "/login": unsupported protocol scheme ""`** → `lab.tfvars` is
  shadowing real credentials with placeholder strings. Each directory's
  `README_LAB.md` covers this.
- **APIC reachable but `terraform plan` fails on `aaaLogin`** → password
  expired, IP changed, or `TF_VAR_*_apic_password` not exported in current
  shell. Run `make auth-check` in `apic-vmware/`.
- **NDO returns "VRF EUR-X must be deployed on Fabric Y before BD …"** →
  Phase 2 was done out of order. Undeploy and redeploy in the table order.

---

## Production cutover

Production swaps URLs, credentials, and CI jobs (manual triggers, masked
variables, GitLab HTTP state backend). The phase order is the same. The
operational deltas live in:

- `ndo-terraform-nac-prod/README.md` — production NDO target
- `aci-redesign/apic-vmware-prod/README.md` — production APIC root (separate
  Terraform state from `apic-vmware/`)
- `aci-redesign/README.md` "Production cutover runbook" — coordinated UCS /
  vCenter / network-team cutover sequence (separate from the lab build)

---

## What this README deliberately does not cover

- Schema design rationale (2-VRF split, BD/EPG model, ESG plan) →
  `aci-redesign/DESIGN.md`.
- GitLab CI/runner setup, masked variables, CI-side workflow →
  `terraform-esg/README.md`.
- Per-stack troubleshooting catalogs → each stack's own `README.md` /
  `README_LAB.md`.

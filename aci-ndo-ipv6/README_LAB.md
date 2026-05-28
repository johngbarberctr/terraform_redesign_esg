# ndo-terraform-ipv6 — Lab Runbook

Lab-only walkthrough for the IPv6 RCC Terraform stack against the dCloud / lab Nexus Dashboard Orchestrator. Production has its own runbook (forthcoming `README_PROD.md`); do not copy values between the two.

If you've never run Terraform before, you can follow this top-to-bottom and end up with a working `terraform plan`. The original mixed-environment `README.md` is still in this directory for reference and for the GitLab CI/CD pipeline notes.

---

## What this stack actually does (lab)

Manages the legacy IPv6 schema in NDO via the `mso` provider. One template, one VRF, ~360 resources (Bridge Domains, EPGs, contracts) defined in `bds_epgs.tf`. State lives in a local file (`terraform.tfstate`) on your laptop — no GitLab token, no remote backend.

This stack is the IPv6 layer that complements the redesigned IPv4 stack in `../aci-redesign/ndo/`. Both can be active at the same time on the same lab fabrics; they share VRFs and tenants but own disjoint sets of BDs, EPGs, and L3Outs.

| Thing | Lab value |
|---|---|
| NDO endpoint | dCloud lab NDO (currently `https://198.18.133.100`) |
| MSO provider `domain` | `"local"` |
| MSO provider `platform` | `"nd"` |
| VRF template name | `VRF_Template` (set via `lab.tfvars`; production uses `prod.tfvars` which sets `UpgradeTemplate1`. CI selects via `TF_VARS_FILE` — defaults to `lab.tfvars`.) |
| Terraform state (laptop) | local file (this directory) via `local_override.tf` |
| Terraform state (CI) | GitLab HTTP backend at `…/projects/<project_id>/terraform/state/ndo-terraform-ipv6`, authenticated with `${CI_JOB_TOKEN}` |
| GitLab CI/CD | wired for both lab and prod against the same `.gitlab-ci.yml`; per-project CI variables (`NDO_URL` / `NDO_USERNAME` / `NDO_PASSWORD`) are set independently on each GitLab project. See [`README.md` → "CI/CD Pipeline"](README.md#cicd-pipeline). |

> **You can run this stack from CI.** Push to a branch / open MR for plan; merge to `main` (or run pipeline manually with `PROJECT=ndo-terraform-ipv6`) for plan + apply (apply is a manual button — never auto). State stays in the GitLab HTTP slot. The walkthrough below is the **laptop** path, which is what most operators use day-to-day for this stack because of the long plan times (~30 minutes) and the desire to eyeball the diff before clicking apply.

---

## Prerequisites

- macOS with Homebrew, or any RHEL host with internet access for provider downloads.
- Terraform 1.5+ installed (`brew install terraform`). The current state was last written by `1.12.2`.
- Network reach to the lab NDO management IP (you'll need to be on the dCloud / lab VPN).
- Lab NDO credentials (admin or a NAC-equivalent service account).
- An NDO (Orchestration) service that is actually running on the lab Nexus Dashboard cluster. On a fresh dCloud "ND 4.1" topology this is **not** the default — see "Bootstrapping NDO on a fresh dCloud ND 4.1" below.

Verify Terraform:

```bash
terraform version
# Terraform v1.12.2 or later
```

---

## Bootstrapping NDO on a fresh dCloud ND 4.1

**Skip this section if your lab NDO is already up and you can `curl /login` against it.** Do it once per fresh dCloud Topology Builder build, *before* anything in "One-time setup" — without it, the MSO provider can't authenticate and every `data.mso_*` read times out.

dCloud's "Nexus Dashboard 4.1" image installs **NDFC** and **Insights** automatically; it does **not** install NDO (Orchestration). On a single-node vND, the cluster UI's "Enable Orchestration" toggle hangs on `Enabling / Disabling Orchestration feature is in progress. This may take a while.` indefinitely (1+ hour observed) and never completes. The [Cisco ND 4.1 prerequisites guide](https://www.cisco.com/c/en/us/td/docs/dcn/nd/4x/deployment/cisco-nexus-dashboard-deployment-guide-41x/nd-prerequisites-41x.html) recommends the built-in swagger UI to enable Orchestration on single-node lab clusters, but in practice the path it tells you to search for (`/settings/general/actions/enableOrchestration`) is buried in a collapsed sub-menu — and on some 4.1 builds the explicit action endpoint isn't even surfaced in the in-product swagger. The reliable path is the underlying `licensetier` API directly.

### Before you start

- **Disable NDFC and Insights** from the ND cluster UI if dCloud auto-started them — NDO won't install while they're co-resident on a single-node vND.
- Confirm the license tier is **Advantage** or **Premier**. Essentials does not include NDO.
- Have an ND admin login (the same one you'll later put in `terraform.tfvars` / `TF_VAR_ndo_password`).

### Enable Orchestration via the `licensetier` API (recommended)

Substitute your real ND host and admin password (the dCloud default for a fresh 4.1 image is `C1sco12345`):

```bash
ND=https://198.18.133.100
ND_USER=admin
ND_PASS='<your-nd-admin-password>'

# 1. Cluster login -> JWT
TOKEN=$(curl -sk -X POST "$ND/login" \
  -H 'Content-Type: application/json' \
  -d "{\"userName\":\"$ND_USER\",\"userPasswd\":\"$ND_PASS\",\"domain\":\"local\"}" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")

[ -n "$TOKEN" ] && echo "JWT obtained: ${TOKEN:0:24}..." || { echo "login failed"; exit 1; }

# 2. Set the tier and register cisco-mso (this is what enableOrchestration does internally)
curl -sk -X POST "$ND/api/v1/licensetier" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"licenseTier": "Premier", "apps": ["cisco-mso"]}'
echo
```

The `licensetier` POST returns either `{}`, `204 No Content`, or a small status payload. It does **not** return immediately-usable orchestration; enablement is asynchronous and takes 2–5 minutes on a single-node vND.

### Verify NDO came up

After waiting a couple of minutes, check the ND service list. The presence of `cisco-mso` (and its eventual transition to `Healthy`) is the green light:

```bash
curl -sk -H "Authorization: Bearer $TOKEN" "$ND/api/v1/services" \
  | python3 -m json.tool | grep -i mso
```

If nothing comes back after 10 minutes, the most common culprits are NDFC/Insights still co-resident on the single-node vND, or licensetier was rejected (re-run the step 2 POST and check the response body).

The same login probe you'll use from Terraform also doubles as a smoke test:

```bash
curl -sk -X POST "$ND/login" \
  -H 'Content-Type: application/json' \
  -d "{\"userName\":\"$ND_USER\",\"userPasswd\":\"$ND_PASS\",\"domain\":\"local\"}"
```

A valid response includes a `token` field. Once both the service list shows `cisco-mso` and `/login` returns a token, proceed to "One-time setup".

### Optional: enable from the in-product swagger UI

The Cisco docs walk you through this; it's the same outcome via the same `licensetier` plumbing under the hood, just clickier and more menu-spelunky. Use only if you want to keep the runbook fully UI-driven, or if you need to verify the `licensetier` API call did what you expected.

1. From the ND UI: top-right `?` → **Help Center** → **API reference: Swagger (In-product)**.
2. Make sure you're on the **cluster-level** swagger (the URL bar should still be the ND host root, not a service tab like NDFC or Insights).
3. Left nav → **Infra** group → **expand the `System Settings` sub-menu**. This is the gotcha: the sub-menu is collapsed by default and `Ctrl+F` won't find anything inside its body until you click to expand. The docs' "search for `/settings/general/actions/enableOrchestration`" instruction therefore returns no results until then.
4. Find `POST /settings/general/actions/enableOrchestration`.
5. Expand → **Try it Out** → **Execute**.

If you still can't find the endpoint after expanding `System Settings`, the explicit action isn't exposed in your build's swagger — fall back to the `licensetier` recipe above.

---

## One-time setup

### 1. Confirm the local state override is in place

This file makes Terraform use a local state file instead of GitLab. It's gitignored (`*_override.tf`) so it never leaves your laptop and CI never sees it.

```bash
cd ~/DC/ACI/terraform-esg/ndo-terraform-ipv6
ls local_override.tf  # should exist
```

If it's missing (e.g. you wiped the directory):

```bash
cat > local_override.tf <<'EOF'
terraform {
  backend "local" {}
}
EOF
```

### 2. Set your lab NDO credentials

Two reasonable patterns. Pick one. Do not commit credentials.

**Option A — environment variables (recommended for daily use):**

```bash
export TF_VAR_ndo_username='admin'
export TF_VAR_ndo_url='https://198.18.133.100'
read -s TF_VAR_ndo_password   # type the password, then Enter
export TF_VAR_ndo_password
```

Add the non-secret two to your `~/.zshrc` if you're tired of re-exporting them; keep the password interactive or in a password manager.

**Option B — a local `terraform.tfvars` file (gitignored):**

```bash
cat > terraform.tfvars <<'EOF'
ndo_username = "admin"
ndo_password = "<paste lab password>"
ndo_url      = "https://198.18.133.100"
EOF
chmod 600 terraform.tfvars
```

> **tfvars convention in this directory** (don't mix layers, or you'll get silent overrides):
>
> | File | Tracked? | Auto-loaded? | Holds | Pass via |
> |---|---|---|---|---|
> | `terraform.tfvars` | gitignored | yes | active credentials + NDO URL only | n/a |
> | `lab.tfvars` | **tracked** | no | env config: `vrf_template_name`, `mso_domain`, `mso_platform` | `-var-file=lab.tfvars` |
> | `prod.tfvars` | **tracked** | no | env config: `vrf_template_name` (production value) | `-var-file=prod.tfvars` |
>
> `lab.tfvars` / `prod.tfvars` are committed via `!lab.tfvars` / `!prod.tfvars` allow-list lines in `.gitignore` because they hold only non-secret env knobs and CI reads them via `-var-file=${TF_VARS_FILE}` on a fresh clone. Do NOT add credentials to `lab.tfvars` or `prod.tfvars` — credentials live in `terraform.tfvars` (gitignored, auto-loaded) only, and putting them in the tracked files would both leak secrets and override `terraform.tfvars` at plan time.

### 3. Initialize Terraform

```bash
terraform init
```

You should see `Successfully configured the backend "local"!` and provider downloads for `ciscodevnet/mso ~> 1.5.0` and `ciscodevnet/aci 2.18.0`. No GitLab Personal Access Token is needed.

If you see `HTTP remote state endpoint requires auth`, the override file went missing — recreate it (step 1) and re-run.

### 4. Starting from an empty NDO lab (state reset)

Skip this step if NDO already contains the IPv6 schema and `bds_epgs.tf` matches what's deployed. Do this step if NDO has been wiped/rebuilt and the local `terraform.tfstate` still references resources that no longer exist (e.g. an old `schema_id` like `6995924db9f119d49048b11d`). Symptom: `terraform plan` shows hundreds of `-/+ ... must be replaced` lines, all driven by `~ schema_id = "OLD" -> "NEW" # forces replacement`.

**Drop the stale state and start fresh:**

```bash
cd ~/DC/ACI/terraform-esg/ndo-terraform-ipv6
mv terraform.tfstate terraform.tfstate.pre-ipv6-rebuild-$(date +%F)
mv terraform.tfstate.backup terraform.tfstate.backup.pre-ipv6-rebuild-$(date +%F) 2>/dev/null || true
terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 -out=plan.tfplan
```

The new plan should be adds-only (`Plan: N to add, 0 to change, 0 to destroy`). The renamed files are kept locally as a rollback artifact and are gitignored along with the live state.

> **Why not `terraform apply -refresh-only` instead?** Tempting, but it does not fix this scenario. Refresh-only reconciles state against live NDO; it does not re-evaluate config. When `schema_id` changes in code (or via the `data.mso_schema.existing` data source pointing at a rebuilt schema), the divergence is between **state and config**, not between **state and NDO** — so refresh-only just reports `No changes. ... 0 added, 0 changed, 0 destroyed.` and the next plan still shows the full destroy/recreate cycle. Use refresh-only only when you genuinely suspect drift from out-of-band changes against the *same* schema (see "Periodic full refresh" under Daily workflow).

Sanity-check with a no-op plan before the real one:

```bash
terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 \
  | grep -E '^Plan:|to destroy'
```

You want `Plan: <some number> to add, 0 to change, 0 to destroy.` If you see anything destroying, stop and investigate — do not apply.

---

## Daily workflow

```bash
cd ~/DC/ACI/terraform-esg/ndo-terraform-ipv6
terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 -out=plan.tfplan
terraform apply -parallelism=3 plan.tfplan
```

That's the whole loop. Two flags matter and you should not change them lightly:

| Flag | Why |
|---|---|
| `-refresh=false` | NDO API throttles aggressively; a full state refresh on 360+ resources triggers session timeouts and provider crashes mid-plan. Trust the existing state and only act on `.tf` changes. Plan-only flag. |
| `-parallelism=3` | Empirically the sweet spot. Higher values trigger NDO session drops and provider crashes; lower values (1–2) also fail or hang intermittently in this stack. Don't change without a reason. **Pass it on `apply` too** — Terraform's saved plan file does not persist `-parallelism`, so `terraform apply plan.tfplan` (without the flag) falls back to the default of 10 and re-triggers the same throttling problem. |

### Periodic full refresh (off-hours)

If you suspect the state file is out of sync with what's actually in NDO (someone clicked in the UI, you imported a resource, you reverted a change manually):

```bash
nohup terraform plan -parallelism=3 > refresh_$(date +%F).log 2>&1 &
```

Expect 30+ minutes and intermittent auth errors — re-run as needed.

### Targeted operations

```bash
# Plan a single resource
terraform plan -refresh=false -parallelism=3 \
  -target=mso_schema_template_bd_subnet.bd_fmwr_svr_subnet

# Refresh a single resource against live NDO
terraform plan -refresh=true -parallelism=3 \
  -target=mso_schema_template_bd_subnet.bd_fmwr_svr_subnet
```

### Where the lab pieces fit together

The full lab workflow looks roughly like:

1. `aci-redesign/ndo/` — deploy the redesigned IPv4 schema to NDO (creates VRFs, BDs, EPGs).
2. `aci-redesign/apic-vmware/` — deploy the APIC + VMware VMM domain pieces.
3. **`ndo-terraform-ipv6/` (this stack)** — deploy IPv6 BDs, EPGs, and contracts from `bds_epgs.tf`. **L3Outs and VLAN pools are intentionally deferred** to step 6 (see "Deferred — re-enable after bindings" below).
4. NDO UI — manually deploy the templates Terraform created (this stack uses `deploy_templates = false`).
5. `../scripts/deploy_bindings.py` (or equivalent) — push static port bindings that NAC YAML doesn't model. Activate the shared Python venv first: `source ~/dc_redesign/bin/activate` (bootstrap is in [`../README.md`](../README.md) "One-time setup"; the script needs `requests` / `urllib3` / `PyYAML`).
6. **Re-enable the deferred files in this directory, in order:** `l3outs_ndo.tf.disabled` → wait for NDO sync to APIC → `l3outs_apic.tf.disabled` → `vlans_apic.tf.disabled`. See **"Deferred — re-enable after bindings"** under "What's in this directory" for the rename / uncomment / apply sequence.
7. vCenter — verify port groups appear under the per-fabric VDS.

---

## What's in this directory (lab perspective)

### Active Terraform files (used)

| File | Lines | Purpose |
|---|---|---|
| `main.tf` | 23 | `backend "http" {}` (overridden locally), provider versions, MSO provider config |
| `variables.tf` | 39 | `ndo_*`, `vmm_domain_name`, `vrf_template_name`, `mso_domain`, `mso_platform` |
| `bds_epgs.tf` | 4181 | The whole IPv6 model: 361 resources (BDs, EPGs, subnets, contracts) |
| `local_override.tf` | gitignored | Forces local state on your laptop (this file) |
| `terraform.tfvars` | gitignored | Your real lab credentials (auto-loaded) |
| `lab.tfvars` | 18 | Tracked. Env-knob file; not auto-loaded — must pass `-var-file=lab.tfvars` |
| `prod.tfvars` | 14 | Tracked. Production env-knob file; pass `-var-file=prod.tfvars` |

### Deferred — re-enable after bindings

> **Status (lab, AEDCG + AEDCK):** all three stage files are **active** (no `.disabled` suffix). `bds_epgs.tf` manages the VRF, `Any_RCC` contract (vzAny on VRF-RCC), and all BDs/EPGs. `l3outs_ndo.tf` manages the NDO L3Outs and ExtEPGs with the `Any_RCC` contract. `l3outs_apic.tf` manages the OSPF interface policy (`OSPF-IntPol-L3Out`), logical node/interface profiles, and IPv6 SVI path attachments on each APIC. `vlans_apic.tf` creates the `VLAN_All_Combined` static VLAN pool and all 39 encap entries on both APICs.

Three files form a strict ordered chain. They must be applied in sequence after `bds_epgs.tf` is in NDO and static port bindings have been pushed (workflow step 5). To deactivate one, rename `*.tf` → `*.tf.disabled`; to reactivate, rename back.

| Stage | File | Provider | Manages | Hard prerequisite |
|---|---|---|---|---|
| 6a | `l3outs_ndo.tf` | `mso` | Site-local L3Outs (`L3Out-RCC-E-G`, `L3Out-RCC-E-K`), External EPGs (`ExtEPG-RCC-E-G/K`), `Any_RCC` contract consumer/provider on each ExtEPG | `bds_epgs.tf` applied (provides `Any_RCC` contract); bindings pushed |
| 6b | `l3outs_apic.tf` | `aci` (per-site aliases `aci.apic_g`, `aci.apic_k`) | OSPF interface policy (`OSPF-IntPol-L3Out` in tenant EUR), logical node/interface profiles, IPv6 SVI path attachments directly on each APIC | Stage 6a applied **and** NDO has pushed the L3Outs to **both** APICs (verify in APIC UI before proceeding) |
| 6c | `vlans_apic.tf` | `aci` (reuses `aci.apic_g`, `aci.apic_k` from stage 6b) | Creates VLAN pool `VLAN_All_Combined` (static) on both APICs and adds 39 encap entries (VLANs 3001–3442) | Stage 6b applied |

**APIC credentials** — stage 6b and 6c both require APIC access. Add to `terraform.tfvars` (gitignored):
```hcl
apic_password = "C1sco12345"
# apic_g_url and apic_k_url default to 198.18.134.252 / 198.18.134.253 — no override needed for lab
# apic_username defaults to "admin" — no override needed for lab
```

**Apply sequence (one stage at a time, plan and verify between each):**

1. **Stage 6a — NDO L3Outs.**
   ```bash
   terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 -out=l3outs_ndo.tfplan
   terraform apply -parallelism=3 l3outs_ndo.tfplan
   # Deploy affected templates from the NDO UI; confirm both APICs show
   # L3Out-RCC-E-G / L3Out-RCC-E-K under tn-EUR before doing stage 6b.
   ```
2. **Stage 6b — APIC L3Out details.** Remove the `/* ... */` block comment wrapping the resources before planning (the file ships commented to prevent accidental apply before the parent L3Out exists):
   ```bash
   # edit l3outs_apic.tf: delete the line containing only `/*` (around line 135)
   # and the matching `*/` near the end of the file
   terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 -out=l3outs_apic.tfplan
   terraform apply -parallelism=3 l3outs_apic.tfplan
   # Creates: OSPF-IntPol-L3Out, NodeProfile-RCC-E, IntProfile-RCC-E, SVI path attachments
   ```
3. **Stage 6c — VLAN pool and entries.**
   ```bash
   terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 -out=vlans_apic.tfplan
   terraform apply -parallelism=3 vlans_apic.tfplan
   # Creates: VLAN_All_Combined (static) pool + 39 encap entries on AEDCG and AEDCK
   ```

**Rolling back a stage:** rename `*.tf` → `*.tf.disabled` **before** the next plan. If you skip the rename, Terraform sees the resources as removed from config and plans a destroy against live infrastructure. For stage 6b specifically, if you want to keep the providers loaded but not the resources, re-wrap the resource block in `/* ... */` instead of renaming the file.

### Truly inactive — leave alone

Files ending in `.disabled`, `.offline`, `.offlineold`, `.offfline`, `.backup` that aren't in the deferred table above. Terraform only reads `*.tf`, so these are inert. Notable:

- `eur_consolidated.tf.disabled` — old monolith, replaced by `bds_epgs.tf`
- `l3outs_apic.tf.disabled.old` — earlier revision of stage 6b kept for diff/recovery; do **not** rename this file. If you need something out of it, diff against `l3outs_apic.tf`.
- `vhost_mgmt*.tf.disabled` — host-management constructs no longer in scope
- Any `.offline` / `.offlineold` / `.offfline` (typo) files — historical staging artifacts; safe to delete once you've confirmed they aren't needed

### Generated / runtime — gitignored

- `terraform.tfstate`, `terraform.tfstate.backup` — local state
- `.terraform/`, `.terraform.lock.hcl` — provider cache and lockfile
- `plan.tfplan` — most recent plan
- `terraform_debug.log` — TF_LOG output if you ran with debug
- `vault.yml`, `vault_pass.txt` — Ansible vault for the password (alternative to env vars)

---

## Troubleshooting

### `Error: Error loading state: HTTP remote state endpoint requires auth`

The `local_override.tf` file is missing, so Terraform fell back to the empty `backend "http" {}` in `main.tf`. Recreate it (see Setup step 1) and `terraform init -reconfigure`.

If `-reconfigure` then errors with **"Backend configuration changed"**, or if `terraform.tfstate` has been truncated to 0 bytes while `terraform.tfstate.backup` is multi-MB, you're in the failed-migration corner case. Follow the canonical 5-step recovery in `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/README.md` → "Recovery: stuck on backend errors after running `terraform init`": paranoia copy → ensure `local_override.tf` → restore `terraform.tfstate` from `.backup` → `terraform init -reconfigure` → `plan -refresh=false`. Same sequence works in this directory; only the path differs.

### `Error: Post "/login": unsupported protocol scheme ""`

`var.ndo_url` resolved to a value with no scheme — e.g. the literal string `<lab NDO URL>` rather than `https://198.18.133.100`. Almost always means `lab.tfvars` (or `prod.tfvars`) still contains the original placeholder credentials and is overriding the real values from `terraform.tfvars`. Fix by removing `ndo_url`, `ndo_username`, `ndo_password`, `vmm_domain_name` lines from `lab.tfvars` / `prod.tfvars` (those files should hold env config only — see Setup step 2).

### `Error: 401 Unauthorized` from the MSO provider

Your `ndo_username` / `ndo_password` are wrong, or you're not on the lab VPN, or the lab NDO certificate is mid-rotation. Sanity-check:

```bash
curl -sk -X POST "$TF_VAR_ndo_url/login" \
  -H 'Content-Type: application/json' \
  -d "{\"userName\":\"$TF_VAR_ndo_username\",\"userPasswd\":\"$TF_VAR_ndo_password\",\"domain\":\"local\"}"
```

A valid response includes a `token` field. A 401 here proves the credentials, not Terraform, are the problem.

### `Warning: Value for undeclared variable "vmm_domain_name"`

Lingering legacy variable. The variable was removed from `variables.tf` but `lab.tfvars` / `prod.tfvars` still mention it. Delete the `vmm_domain_name` line from those tfvars files and the warning goes away. The two `mso_schema_site_anp_epg_domain.epg_nac_vmm_domain_*` resources currently in state will plan as destroyed (they no longer exist in `bds_epgs.tf`); that's expected.

### Provider crashes mid-plan, "session expired" errors

NDO throttling. Stay at `-parallelism=3` and re-run with `-refresh=false`; dropping below 3 has historically made things worse, not better. If it still fails, NDO is genuinely overloaded — wait 5 minutes and retry at 3.

### `terraform plan` shows hundreds of changes you didn't make

The state is out of sync with NDO. Either someone changed things in the UI, the NDO schema was rebuilt (different `schema_id`), or the state file is genuinely stale. Check the state's last-write timestamp with `stat -f '%Sm' terraform.tfstate` (macOS) or `stat -c '%y' terraform.tfstate` (Linux). If hundreds of `-/+ ... must be replaced` lines all reference a `schema_id` change (`OLD -> NEW # forces replacement`), jump to **Setup step 4 (Starting from an empty NDO lab)** — `terraform apply -refresh-only` will silently report `No changes` here and not help, because the divergence is config-vs-state, not state-vs-NDO. Otherwise run a periodic full refresh (above) before doing anything destructive.

### `Error acquiring the state lock`

Local state has no lock service, so this is almost always a stale lock from a previous interrupted run. Check `.terraform.tfstate.lock.info` and remove it if no `terraform` process is running:

```bash
ls -la .terraform.tfstate.lock.info 2>/dev/null
# if no terraform process is alive:
rm .terraform.tfstate.lock.info
```

### `git status` shows `local_override.tf` (it shouldn't)

The `*_override.tf` rule on line 18 of `.gitignore` should hide it. Confirm:

```bash
git check-ignore -v local_override.tf
# expected: .gitignore:18:*_override.tf	local_override.tf
```

If the rule is missing, your `.gitignore` was clobbered — restore from `git show HEAD:ndo-terraform-ipv6/.gitignore`.

---

## What this README deliberately does not cover

- **Production deployment** — see `README_PROD.md` (forthcoming) and the existing `README.md` GitLab CI/CD section. Lab and prod use different NDO instances, different VRF template names, different state backends.
- **Modifying the schema** — `bds_epgs.tf` is hand-curated; before touching it, read `NDO_TERRAFORM_PRESENTATION.md` in this directory.
- **Static port bindings** — handled outside Terraform by `generate_ipv6_bindings3.py`. Run from inside the shared `~/dc_redesign` venv (`source ~/dc_redesign/bin/activate`); see [`README.md`](README.md) "Python Virtual Environment" for the bootstrap. The script's defaults are Design A port-channel bindings only (PC_FI_A/B on AEDCG 152/153, AEDCK 119/191); two opt-in flags layer on:
  - `--inherit-from-ipv4` copies binding *shape* from the legacy IPv4 reference EPGs in the same schema. Default OFF because those references carry legacy Design B (`VPC_D*A-B / protpaths`).
  - `--ports-override <file.json>` appends or replaces per-EPG bindings from a JSON file. Use this to add **individual interface** bindings (`type='port'`, e.g. `eth1/x`) — the default code path never emits these. See `ports_override.example.json` in this directory for the file shape; shorthand `{site, leaf, port}` expands to `topology/pod-1/paths-{leaf}/pathep-[{port}]` automatically.

  The script also ties into the `../scripts/deploy_bindings.py` flow.
- **The CI pipeline** — see [`README.md` → "CI/CD Pipeline"](README.md#cicd-pipeline). The pipeline drives plan + manual-apply for both lab and prod (per-project GitLab CI variables decide which NDO it talks to). This walkthrough is laptop-driven because most operators want to eyeball the long plan diff before applying; CI is fully supported but less commonly used day-to-day for this stack.

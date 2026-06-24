# End-to-End Lab Deployment Runbook

**This is THE canonical runbook for deploying the lab from scratch.** It covers
both `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo` and the sibling `sac-johbarbe-AFRICOM-terraform-nac-ndo` repo, in the
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
~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/    # sibling repo — Phase 1 only
~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/             # this repo — Phases 3, 4, 5, 6
GitLab UI                            # Phase 2 (manual NDO template deploys)
                                     # and triggering apply jobs
```

For each Terraform root you'll work in, the **first time only** do this:

1. Clone the repo and `cd` into the root (e.g. `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/` for Phase 1, `aci-ndo/` for Phase 4, etc.).
2. Decide between **laptop runs** (this runbook) or **CI runs** (push to `main`, let the GitLab pipeline drive it). Pick one per session.
3. **Laptop runs only**: drop a gitignored `local_override.tf` containing `terraform { backend "local" {} }` so Terraform uses a local state file instead of trying to talk to GitLab. This is gitignored at the repo root via the `*_override.tf` rule and never reaches CI:

   ```bash
   cat > local_override.tf <<'EOF'
   terraform { backend "local" {} }
   EOF
   ```
4. Set per-project credentials. Per-stack: `.env` for `nac-prod` (Phase 1); `terraform.tfvars` + `TF_VAR_ndo_password` for `aci-ndo/` (Phase 4); `lab.tfvars` + `terraform.tfvars` for `aci-ndo-ipv6/` (Phase 5). Each phase below shows the exact commands.
5. `terraform init`, then `terraform plan`, then `terraform apply` — exactly as Phase N below shows.

After every Terraform `apply` against an NDO stack, **the changes are in NDO but NOT yet on the APICs**. Each NDO stack ends with a manual NDO-UI **Deploy to sites** step. The phases below show the order and target sites for each.

If you'd rather drive everything through CI: skip the `local_override.tf` step, do [Phase 0](#phase-0--bootstrap-gitlab-cicd-variables-optional-prerequisite-for-ci-runs-only) below (~5 min, one interactive script per repo) to provision the GitLab CI/CD variables, then commit + push and GitLab runs validate + plan automatically. Apply is **manual** (button in the UI) for every stack except `nac-prod`, where it auto-runs on `main` (safe because `deploy_templates = false`). The state backend uses `${CI_JOB_TOKEN}` — the bootstrap scripts also set up the long-lived `TF_HTTP_PASSWORD` fallback used for state operations from your laptop, so you don't manage two tokens. See [`README.md`](README.md) → "CI/CD pipeline" for the per-job detail.

---

## Documentation map

```
~/DC/ACI/
├── sac-johbarbe-AFRICOM-terraform-nac-ndo/                    [Phase 1 — separate repo]
│   ├── README.md                              prod NDO-NAC reference
│   └── README_LAB.md                          lab toggle walkthrough
│
└── sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/
    ├── README.md                              repo intro + GitLab CI/runner setup
    ├── README_LAB.md                          THIS FILE — end-to-end runbook
    ├── PROJECT_MAP.md                         server/path/CI cross-reference
    ├── PROJECTS_LISTING.md                    every Mac project + remotes
    │
    ├── aci-apic/                              [Phase 3 — APIC fabric/VMM, lab + prod]
    │   ├── README.md                          reference (env vars, errors)
    │   ├── lab.tfvars                         lab APIC URLs + manage_tenants=true
    │   ├── prod.tfvars                        prod APIC URLs + manage_tenants=false
    │   └── data/                              per-fabric NAC YAML inputs
    │       ├── nac-aci-shared/                shared tenant/ESG YAML
    │       ├── nac-aci-site1/                 Kelley fabric-specific YAML
    │       └── nac-aci-site2/                 Del-Din fabric-specific YAML
    │
    ├── aci-ndo/                               [Phase 4 — IPv4 redesign tenant tree]
    │   ├── README.md                          reference (cutover, schema)
    │   └── data/nac-ndo/                      NDO YAML (AFRICOM-V2 schema)
    │
    ├── scripts/                               [Phase 6 — bindings push tools]
    │   └── README.md                          CLI reference (dump_bindings,
    │                                          deploy_bindings, generate_fi_bindings)
    │
    └── docs/                                  architecture docs
        ├── DESIGN.md                          2-VRF redesign rationale, BD/EPG model
        └── REDESIGN.md                        production cutover runbook
    │
    ├── aci-ndo-ipv6/                    [Phase 5 — IPv6 RCC layer]
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
| 0 *(optional)* | Bootstrap the two GitLab projects' CI/CD variables (prerequisite for CI-driven runs only) | `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/` + `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/` | ~5 min total | One script per repo, mostly auto-discovered |
| 1 | Build foundational NDO state (tenant `AFR-DEL.Services`, schema `AFRICOM`, 4 templates) | `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/` | ~10 min plan/apply | Terraform |
| 2 | Deploy 4 templates to Kelley/Del-Din (in strict order) | NDO UI | ~15 min total | **Manual UI** |
| 2.5 | Push legacy N5K static port bindings to AFRICOM EPGs | `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/scripts/` | ~2 min | Python (`deploy_bindings_python_v2.py`) |
| 3 | APIC fabric/access policies, MCP, VMware VMM domains | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-apic/` | ~5 min apply | Terraform (both fabrics in one root) |
| 4 | V2 redesign tenant tree (schema `AFRICOM-V2`, template `Tenant_EUR_V2`; all tenant-scoped objects suffixed `-V2`) | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo/` | ~5 min apply + UI deploy | Terraform + manual UI |
| 5 *(optional)* | IPv6 RCC layer (adds `AppProf-RCC` to existing `Stretched_Services`) | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo-ipv6/` | ~30 min apply at `-parallelism=3` | Terraform + manual UI re-deploy |
| 6 | Static port bindings (post-deploy push not modeled in NAC YAML) | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/scripts/` | ~2 min | Python + manual UI re-deploy |
| 7 | Verify on APICs and vCenter | APIC GUI + vCenter | as needed | Manual |

Phase 5 is optional **only** if you take Phase 6 Path B (`generate_fi_bindings.py`).
If you take Phase 6 Path A (`dump_bindings.py`), Phase 5 is a hard prerequisite.

---

## Phase 0 — Bootstrap GitLab CI/CD variables *(optional, prerequisite for CI runs only)*

Skip this phase entirely if you plan to run everything from your laptop with `local_override.tf` (the path the rest of this runbook assumes by default).

Read this phase if you want GitLab CI to drive `terraform plan` / `terraform apply` for any of Phases 1, 3, 4, or 5. The GitLab project that hosts each repo needs:

- `sac-johbarbe-AFRICOM-terraform-nac-ndo`: 6 variables — `MSO_URL`, `MSO_USERNAME`, `MSO_PASSWORD` (mask+protect), `MSO_DOMAIN`, `TF_HTTP_USERNAME`, `TF_HTTP_PASSWORD` (mask).
- `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo`: 18 variables — `NDO_*`, `KELLEY_APIC_*`, `DELDIN_APIC_*`, `VCENTER_*`, `TF_HTTP_*` (lab set, with masked/protected flags per project policy). The `_PROD`-suffixed variant for `apic-vmware-prod` is provisioned later via the same script with `--prod` (or on a separate production GitLab) — see the "Production cutover" subsection below.

Provisioning these by hand through the GitLab UI is slow and error-prone (~24 clicks per repo). Each repo ships an interactive bootstrap script under `scripts/` that:

- auto-discovers values from your local `.env` / `terraform.tfvars` (lab APIC URLs, NDO password, MSO domain, etc.)
- silently prompts only for what it can't (GitLab PAT, APIC admin password, vCenter creds)
- auto-generates 16-char MCP keys in an alphabet that satisfies both APIC's complexity policy and GitLab's stricter masked-variable validator
- auto-creates the GitLab project itself on first run (in the case of `sac-johbarbe-AFRICOM-terraform-nac-ndo` if you haven't pushed the repo yet)
- auto-downgrades any value that can't be masked (e.g. `C1sco12345!` — the `!` is outside GitLab's masked-variable alphabet) to `masked=false, protected=true` instead of failing
- contains no secrets and never echoes any value — only the variable name and the flags actually applied

```bash
# 0.1 Bootstrap the foundational NDO project (also creates the GitLab project on first run).
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo
./scripts/setup_gitlab_ci_variables_interactive.sh

# 0.2 Bootstrap the ACI redesign + IPv6 project.
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo
./scripts/setup_gitlab_ci_variables_interactive.sh
```

Both scripts will prompt you for a GitLab Personal Access Token. Generate one at:

```
http://<your-gitlab>/-/user_settings/personal_access_tokens
```

Settings: name = `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo ci`, scope = `api`, expiration = your policy. The same token doubles as the state-backend credential (`TF_HTTP_PASSWORD`), so you only mint one.

After Phase 0:
- `Settings → CI/CD → Variables` on each GitLab project shows the variables with the expected mask/protect flags.
- Mark `main` (or whichever branch you deploy from) as Protected in `Settings → Repository → Protected branches` so the `protected=true` variables actually inject into runs.
- Push to `main` and the per-project `.gitlab-ci.yml` jobs (validate, plan, manual apply) take over for the phases that follow.

Re-run either script at any time — they're idempotent (POST to create, PUT to update) and only touch variables whose env var is set in the current shell.

Details: each repo's `README.md` → "Provisioning the … variable set in one shot" (full env-var table, mask-validator behaviour, troubleshooting).

### Phase 0 — Production cutover *(when you're ready to go live)*

Phase 0 above provisions the **lab** variable set. When you cut over to production you have two patterns; pick the one that matches your environment.

**Pattern A — Separate GitLab instance for production (recommended).** Lab CI lives on the lab GitLab server, production CI lives on a different GitLab server. Both projects use the same variable *names* but different *values*. Re-run the lab scripts pointed at production:

```bash
# sac-johbarbe-AFRICOM-terraform-nac-ndo, prod GitLab:
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo
# Uncomment the prod block (and comment out the lab block) at the top of .env first.
GITLAB_URL=https://gitlab.prod.example.com \
GITLAB_PROJECT=team/sac-johbarbe-AFRICOM-terraform-nac-ndo \
  ./scripts/setup_gitlab_ci_variables_interactive.sh

# sac-johbarbe-AFRICOM-terraform-esg-nac-ndo, prod GitLab:
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo
GITLAB_URL=https://gitlab.prod.example.com \
GITLAB_PROJECT=team/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo \
  ./scripts/setup_gitlab_ci_variables_interactive.sh
```

You'll be prompted for the *production* NDO password, APIC admin password, and vCenter creds. Everything else (URLs, usernames, NDO_DOMAIN, etc.) is auto-discovered from your local tfvars/`.env`. No `--prod` flag is needed in this pattern because there is no name collision between lab and prod variables — they live on different GitLab servers.

**Pattern B — Same GitLab project hosts both lab and prod CI.** This is what `apic-vmware-prod/.gitlab-ci.yml` is designed for: it reads `KELLEY_APIC_PASSWORD_PROD` (etc.) so both lab and prod APIC variables can coexist on one project. For this pattern, run the lab bootstrap first to populate the 18 lab variables, then re-run the wrapper with `--prod` to add the 8 `_PROD` APIC variables alongside them:

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo
./scripts/setup_gitlab_ci_variables_interactive.sh           # lab pass (one-time, already done in Phase 0 above)
./scripts/setup_gitlab_ci_variables_interactive.sh --prod    # prod cutover: adds KELLEY_*_PROD + DELDIN_*_PROD only
```

`--prod` mode:

- prompts for both production APIC URLs (`KELLEY_APIC_URL_PROD`, `DELDIN_APIC_URL_PROD`), the production APIC admin password, and (silently) generates fresh `KELLEY_MCP_KEY_PROD` / `DELDIN_MCP_KEY_PROD` values
- does **not** touch `NDO_*`, `VCENTER_*`, or `TF_HTTP_*` — those are either shared between lab and prod (the per-project CI files have no `_PROD` variant for them) or already set in the lab pass
- still validates the GitLab PAT length and downgrades any value that can't be masked, exactly like the lab pass

`sac-johbarbe-AFRICOM-terraform-nac-ndo` has no `--prod` mode because its CI file references only `MSO_*` (one NDO instance is targeted at a time). To repoint that project at production NDO on the same GitLab, edit the values directly in `Settings → CI/CD → Variables`, or re-run its bootstrap with the prod block uncommented in `.env`.

> **Don't forget the IPv6 RCC deferred chain at prod cutover.** The lab already has L3Out-RCC-E-G / L3Out-RCC-E-K and their APIC-side OSPF / interface / VLAN-pool entries live (stages 6a / 6b / 6c). Production starts without them. After production Phases 1 → 5 are applied and Phase 6 bindings have been pushed, replay the same three stages against the prod APICs by following `aci-ndo-ipv6/README_LAB.md` → "Deferred — re-enable after bindings" with prod APIC URLs / credentials in `terraform.tfvars`. Order is still NDO → wait for NDO sync → APIC L3Out details → APIC VLAN entries — same chain, prod values.

---

## Phase 1 — Foundational NDO build (`sac-johbarbe-AFRICOM-terraform-nac-ndo`)

This repo creates **tenant `AFR-DEL.Services`**, **schema `AFRICOM`** with four templates
(`VRF`, `Stretched_Services`, `Kelley_Unique`, `Del_Din_Unique`),
1 VRF (`AFR-PROD`), 266 BDs, 265 EPGs, 2 L3Outs (`L3Out-Kelley`, `L3Out-Del-Din`), and 812 VPC static-port bindings.
Phase 4 in `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo/` cross-references
`AFRICOM / VRF / Any` (the filter), so this phase has to land first.

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo

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

Details: `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/README.md` (architecture, troubleshooting)
and `README_LAB.md` (lab toggle).

---

## Phase 2 — Manual NDO-UI deploy of `AFRICOM` templates

Strict order. Cross-template VRF dependencies will break the deploy if you skip
ahead — error message is "VRF AFR-PROD must be deployed on Fabric Del-Din before
BD type … can be deployed".

NDO UI → **Application Management → Schemas → AFRICOM** → for each template,
click **Deploy to sites** in this order, **waiting for green** between steps:

| # | Template | Sites |
|---|----------|-------|
| 2.1 | `VRF` | Kelley, then Del-Din |
| 2.2 | `Stretched_Services` | Kelley, then Del-Din |
| 2.3 | `Kelley_Unique` | Kelley only |
| 2.4 | `Del_Din_Unique` | Del-Din only |

After Phase 2: tenant `AFR-DEL.Services`, VRF `AFR-PROD`, schema `AFRICOM` with
`Any` filter under `VRF`, all 266 BDs and 265 EPGs are live on Kelley
and Del-Din.

---

## Phase 2.5 — N5K → ACI leaf replacement (`~/DC/NXOS/sac-johbarbe-AFRICOM-nxos-n5k/`)

> **Note:** The 812 VPC static-port bindings deployed in Phase 1 point to the
> existing N5K paths. Phase 2.5 is not the initial binding push — it is the
> cutover process run each time a pair of N5K switches is physically replaced
> with new ACI leaves.

**Physical sequence per N5K replacement:**

1. **Remove the N5K** from the network — powered off and disconnected. The existing NDO bindings for those ports become inactive but remain in the schema.
2. **Install and cable the new ACI leaf** — racked, cabled to the fabric, and discovered by APIC (registered with node ID 101 or 102 at the relevant site).
3. **Configure APIC fabric policies for the new leaf** — switch profile, interface profile, policy groups, and interface selectors (Stage 3 of the toolkit, run against the new leaf node ID).
4. **Push updated bindings to NDO** — the Python script replaces the old N5K port paths with the new ACI leaf paths in the AFRICOM schema (Stage 2 of the toolkit).
5. **Re-deploy affected AFRICOM templates** in the NDO UI so the updated `staticPorts` are pushed to the APICs.

**Before the first replacement** — run Stage 1 once to parse the N5K data and
generate `terraform.tfvars.json`. Re-run Stage 1 if the switch topology changes.

```bash
cd ~/DC/NXOS/sac-johbarbe-AFRICOM-nxos-n5k
source ~/dc_redesign/bin/activate   # needs requests + urllib3 + ansible

# Stage 1 — parse N5K data once (re-run if topology changes)
ansible-playbook ansible/process_all_switches.yml        # lab
# ansible-playbook ansible/process_all_switches_prod.yml  # prod

# Stage 3 — configure APIC fabric for the new leaf (run per replacement)
ansible-playbook ansible/configure_apic_fabric_lab.yml   # lab
# ansible-playbook ansible/configure_apic_fabric.yml      # prod

# Stage 2 — push updated bindings to NDO (dry run first, run per replacement)
python3 scripts/deploy_bindings_python_v2_lab.py terraform.tfvars.json --dry-run
python3 scripts/deploy_bindings_python_v2_lab.py terraform.tfvars.json

# Production (reads credentials from vault.yml via vault_pass.txt)
# python3 scripts/deploy_bindings_python_v2_prod.py terraform.tfvars.json --dry-run
# python3 scripts/deploy_bindings_python_v2_prod.py terraform.tfvars.json
```

For production, `vault.yml` + `vault_pass.txt` must be present and `ndo_host`
in `terraform.tfvars.json` must point at the production NDO. Use `--no-vault`
to read the password from the JSON instead. The binding deploy script is
idempotent — it skips bindings that already exist on NDO.

See `~/DC/NXOS/sac-johbarbe-AFRICOM-nxos-n5k/docs/README_LAB.md` for the full
walkthrough including port classification rules and FEX-to-leaf mapping.

> **TODO (deferred):** Once all N5Ks have been replaced, the old N5K static
> port bindings must be removed from the AFRICOM schema in NDO. Do not do this
> during the replacement window — leave the old bindings in place until all
> switches are swapped and the new leaf bindings are confirmed working. At that
> point, use the NDO UI or the Python script's delete capability to clean up
> the stale N5K paths from each EPG.

---

## Phase 3 — APIC-direct fabric (`aci-apic/`)

Builds access policies and MCP Instance Policies (per fabric, with per-fabric
keys). Manages the UCS Fabric Interconnect uplink access policies (Design A):
`fi-static-vlan-pool` (213 VLANs), `phys-fi-domain`, `fi-aaep`,
`PC_FI_A`/`PC_FI_B` PC policy groups (LACP active), and per-leaf
interface/switch profiles for leaves 101/102 (Kelley) and 101/102 (Del-Din);
and the legacy IPv4 infrastructure objects: `VLAN_All_Combined` static pool
(5 broad ranges, ~2148 VLANs), `PhysDom_ACI_Nexus` physical domain,
`L3_Dom_ND` routed domain, and `AAEP_ACI_Nexus` (used by all N5K migration
VPC/PC policy groups). Independent of Phase 2 — could technically run in
parallel — but in practice do it after.

> **VMM skipped — already in APIC.** The VMM domain objects (`vmm-vlan-pool`,
> `phys-vmm-domain`, `vmm-aaep`, `vpc-vmm-hosts`, `vmm-host-ports`,
> `APCG-VDS1`/`APCK-VDS1` domain definitions) are commented out in all
> `access-policies.nac.yaml` files because AFRICOM already has a VMM domain
> and configuration in APIC. vCenter env vars are **not required** for this
> phase. The `fi-aaep` still carries `phys-fi-domain` for non-VM traffic.

> **No Python venv needed for this phase.** `make` calls bash scripts and
> `terraform` only. The scripts use `python3` stdlib (`json`, `os`, `sys`) for
> JSON escaping — no pip packages required.

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-apic

# 3.1 Lab APIC URLs are already in lab.tfvars (used by default by the Makefile).
#     For prod, edit prod.tfvars instead and pass TFVARS_FILE=prod.tfvars to make.

# 3.2 Sensitive env vars (per shell)
source scripts/set-apic-password.sh                 # both fabrics, same lab password
eval "$(./scripts/generate-mcp-key.sh kelley)"       # TF_VAR_kelley_mcp_key
eval "$(./scripts/generate-mcp-key.sh deldin)"       # TF_VAR_deldin_mcp_key
# NOTE: vCenter env vars (TF_VAR_vcenter_*) are no longer needed — VMM is
#       commented out and render-vmm-yaml.sh is not called.

# 3.3 Init (first time or after module/provider bumps)
make init

# 3.4 Sanity check, plan, apply
make auth-check
make plan
make apply
```

After Phase 3, on each APIC: `fi-static-vlan-pool` (static, 213 VLANs),
`phys-fi-domain`, `fi-aaep` (carries `phys-fi-domain` only — no VMM binding),
`PC_FI_A` and `PC_FI_B` PC policy groups (LACP active), per-leaf interface
profiles for the FI uplinks (eth1/6 on leaf-101, eth1/7 on leaf-102), and the
legacy IPv4 objects: `VLAN_All_Combined` static pool, `PhysDom_ACI_Nexus`,
`L3_Dom_ND`, and `AAEP_ACI_Nexus`.

Details: `aci-apic/README_LAB.md` (lab daily-driver),
`README.md` (env-var table, MCP-key rationale, error catalog).

---

## Phase 4 — V2 (consolidated) tenant tree (`aci-ndo/`)

This is where the cross-schema reference to `AFRICOM/VRF/Any` (built
in Phase 1, deployed in Phase 2) actually resolves. Schema `AFRICOM-V2`
contains a **single template** `Tenant_EUR_V2` (2 VRFs, 39 BDs, 39 EPGs,
2 ANPs, 2 contracts; all tenant-scoped objects suffixed `-V2` to coexist
with the legacy `AFRICOM` schema in tenant `AFR-DEL.Services` — see
[`docs/DESIGN.md` → Naming convention](docs/DESIGN.md#naming-convention);
no static ports — those come in Phase 6).

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo

# 4.1 Non-sensitive bits
test -f terraform.tfvars || cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # ndo_url, ndo_username, ndo_platform, ndo_domain

# 4.2 NDO password (per shell)
source scripts/set-ndo-password.sh

# 4.3 Sanity check, init, plan, apply
make auth-check
make init    # only first time
make plan    # expect: 1 schema (AFRICOM-V2), 1 template (Tenant_EUR_V2),
             #         2 VRFs (-V2), 39 BDs (-V2), 2 ANPs (-V2),
             #         39 EPGs (-V2), 2 contracts (-V2).
             # NO mso_tenant create (manage_tenants=false; AFR-DEL.Services is from Phase 1).
make apply
```

Then NDO UI → **Application Management → Schemas → AFRICOM-V2 →
`Tenant_EUR_V2` → Deploy to sites** → Kelley and Del-Din. **One template here**,
not three (any older docs that say `Tenant_Policy / Stretched_BDs /
App_Profiles` reflect an abandoned design).

After Phase 4: 2 VRFs (`VRF-EUR-V2`, `VRF-DMZ-V2`), 39 BDs, 39 EPGs are live on
Kelley and Del-Din; each EPG is bound to the per-fabric VMM domain from Phase 3
(`APCG-VDS1` on Kelley, `APCK-VDS1` on Del-Din), so 39 port-groups should now
exist on each VDS in vCenter.

### Phase 4b — ESG layer (re-apply `aci-apic/`)

The two Phase-2 ESGs (`ESG-All-Internal-V2`, `ESG-All-DMZ-V2`) and the third ANP `AppProf-AppCentric-V2` that holds them live APIC-direct, in `aci-apic/` (loaded from `data/nac-aci-shared/tenant-eur-esgs.nac.yaml`). They are kept out of the NDO schema because `nac-ndo ~> 1.2.0` and the upstream Cisco `mso` provider `~> 1.7.x` do not model `endpoint_security_groups`; `nac-aci@0.7.0` does. The first apply of `aci-apic/` in Phase 3 lands the access/fabric/MCP/VMM layer; the ESG selectors there reference EPGs that do not exist yet, so they no-op silently. After Phase 4 deploys the EPGs on each APIC, re-apply that root:

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-apic
source scripts/set-apic-password.sh    # if the per-shell var has expired
make plan                              # expect: aci_endpoint_security_group + 39 ESG selector resources per fabric (78 total)
make apply
```

vzAny+permit-all on each VRF (set in Phase 4's NDO schema) keeps the ESGs reachability-neutral — applying them is pure classification, no traffic change. Verify with the APIC GUI rows in [Phase 7](#phase-7--verify) below.

Details: `aci-apic/data/nac-aci-shared/tenant-eur-esgs.nac.yaml` (the ESG YAML itself, with the full Phase-2/Phase-3 design in its header), `docs/DESIGN.md` → "Phase 2 deploy playbook" (rollback path).

---

## Phase 5 *(optional)* — IPv6 RCC layer (`aci-ndo-ipv6/`)

Only do this phase if you need the IPv6 RCC EPGs (`EPG-NAC`, `EPG-CFG-MGMT`,
`EPG-RCC-DNS`, … 39 in total) under a new ANP `AppProf-RCC` inside the
existing `Stretched_Services` template, **and/or** you intend to use Phase 6
Path A (`dump_bindings.py`) which reads from `AFRICOM/AppProf-RCC` to seed
IPv4 bindings.

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo-ipv6

# 5.1 local_override.tf must exist (gitignored, forces local state). If
#     you've already done the laptop-bootstrap step from "TL;DR for someone
#     with no prior knowledge" above, this is already in place.
ls local_override.tf || cat > local_override.tf <<'EOF'
terraform {
  backend "local" {}
}
EOF

# 5.2 Credentials (env vars, NOT in tfvars — see aci-ndo-ipv6/README_LAB.md
#     for why mixing layers causes silent overrides).
export TF_VAR_ndo_url='https://198.18.133.100'
export TF_VAR_ndo_username='admin'
read -rs TF_VAR_ndo_password && export TF_VAR_ndo_password

# 5.3 Init + plan + apply.
#     - `-var-file=lab.tfvars` is REQUIRED: it sets mso_domain="local" +
#       mso_platform="nd" + vrf_template_name="VRF". Omitting it
#       falls back to the variables.tf defaults (null/null/VRF),
#       which makes the mso provider speak legacy-MSO 3.x to a Nexus
#       Dashboard NDO and fail with `HTTP Request failed with status code
#       200 after 3 attempts`. (For prod cutover use `prod.tfvars`.)
#     - `-refresh=false` skips the per-resource GET storm during plan
#       (lab NDO rate-limits and would otherwise time out).
#     - `-parallelism=3` matches the empirically validated NDO sweet
#       spot; higher values trigger session drops.
terraform init
terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 -out=plan.tfplan
terraform apply -parallelism=3 plan.tfplan
```

Then NDO UI → schema `AFRICOM` → template `Stretched_Services` → **Deploy to sites**
again (since this Terraform run added `AppProf-RCC` and 39 IPv6 EPGs into
`Stretched_Services`).

The "Deferred — re-enable after bindings" stages 6a/6b/6c documented in
`aci-ndo-ipv6/README_LAB.md` happen **after** our Phase 6, not before.
**Lab status:** stages 6a/6b/6c are already applied on Kelley/Del-Din — the
`.disabled` files are kept as the replay procedure for production cutover
and DR rebuilds (see that section's "Status" callout for details).

Details: `aci-ndo-ipv6/README_LAB.md` (lab daily-driver), `README.md`
(NDO bootstrap on a fresh dCloud ND 4.1, GitLab CI).

---

## Phase 6 — Static port bindings (`scripts/`)

The NAC YAML doesn't model `staticPorts[]`, so EPGs created in Phase 4 land
on the APICs with no static-port bindings. Phase 6 PATCHes them in via the
NDO REST API. Pick **one** path:

> **Prerequisite — activate the Python venv** (one-time bootstrap covered in
> the top-level `README.md` "One-time setup"). The two scripts that hit NDO
> (`dump_bindings.py`, `deploy_bindings.py`) need `requests` / `urllib3` /
> `PyYAML`; running them against system Python typically fails with
> `ModuleNotFoundError: No module named 'yaml'`.
>
> ```bash
> source ~/dc_redesign/bin/activate
> ```

### Path A — dump from IPv6 RCC (lab default; requires Phase 5)

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/scripts
export NDO_HOST=198.18.133.100
export NDO_USER=admin

# Read AFRICOM/AppProf-RCC, write a JSON for AFRICOM-V2.
# Both sites use nodes 101,102 — pass all four node IDs (Kelley: 101,102; Del-Din: 101,102).
./dump_bindings.py --leaves 101,102,101,102 \
                   --output current_bindings.json --dry-run     # preview
./dump_bindings.py --leaves 101,102,101,102 \
                   --output current_bindings.json               # write

# Review current_bindings.json, decide your VLAN strategy (default strips VLAN
# but deploy_bindings.py requires one — see scripts/README.md).

./deploy_bindings.py current_bindings.json --no-vault --dry-run  # preview
./deploy_bindings.py current_bindings.json --no-vault            # commit
```

### Path B — generate from FI topology (prod default; Phase 5 not required)

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/scripts

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

Whichever path: finish in **NDO UI → schema AFRICOM-V2 → Tenant_EUR_V2 →
Deploy to sites** (re-deploy) so the new `staticPorts[]` push to APIC.

Details: `scripts/README.md` (CLI reference, vault flow, VLAN
strategy rationale).

---

## Phase 7 — Verify

| Where | Check |
|---|---|
| Kelley APIC GUI — FI uplinks | `Fabric → Access Policies → Pools → VLAN → fi-static-vlan-pool` exists (static, 213 VLANs). `fi-aaep` references both `phys-fi-domain` and `APCG-VDS1`. `Interfaces → Leaf Interfaces → Policy Groups → PC_FI_A` and `PC_FI_B` exist (type PC, LACP active). `Profiles → leaf-101-fi-intprof` and `leaf-102-fi-intprof` exist with `fi-a-uplink`/`fi-b-uplink` selectors on ports eth1/6 and eth1/7 respectively. |
| Del-Din APIC GUI — FI uplinks | Same as Kelley. `leaf-101-fi-intprof` (port 6) and `leaf-102-fi-intprof` (port 7). |
| Kelley APIC GUI — legacy objects | `Pools → VLAN → VLAN_All_Combined` exists (static, 5 ranges: 5-54, 66-67, 80-998, 1000-2176, 2205). `Domains → Physical → PhysDom_ACI_Nexus` references `VLAN_All_Combined`. `Domains → L3 → L3_Dom_ND` references `VLAN_All_Combined`. `Global Policies → AEP → AAEP_ACI_Nexus` references both `PhysDom_ACI_Nexus` and `L3_Dom_ND`. |
| Del-Din APIC GUI — legacy objects | Same names and structure as Kelley — `VLAN_All_Combined`, `PhysDom_ACI_Nexus`, `L3_Dom_ND`, `AAEP_ACI_Nexus`. |
| Kelley APIC GUI | `Tenants → AFR-DEL.Services → Application Profiles → AppProf-NetCentric-V2 / AppProf-DMZ-V2` shows 39 EPGs (36 + 3) |
| Kelley APIC GUI (ESG layer) | `Tenants → AFR-DEL.Services → Application Profiles → AppProf-AppCentric-V2 → Endpoint Security Groups` shows `ESG-All-Internal-V2` (in `VRF-EUR-V2`) and `ESG-All-DMZ-V2` (in `VRF-DMZ-V2`); each ESG's `Operational → Endpoints` lists the same endpoints as the corresponding EPGs sum |
| Del-Din APIC GUI | Same as Kelley — both NDO ANPs (39 EPGs) and the APIC-direct AppCentric ANP (2 ESGs) |
| Each EPG's "Domains" tab | Per-fabric VMM domain (`APCG-VDS1` or `APCK-VDS1`) bound, `Resolution Immediacy = Immediate` |
| Each EPG's "Static Ports" tab | Phase 6 bindings present with the right leaf/port/VLAN |
| vCenter | 39 port-groups under each of `APCG-VDS1` / `APCK-VDS1` |
| Phase 5 Phase-Two outcome (if done) | `AppProf-RCC` ANP visible in `Tenants → AFR-DEL.Services → Application Profiles` with 39 IPv6 EPGs |

If anything is missing on the APIC: re-check that you clicked **Deploy to
sites** after the relevant Terraform `apply`.

---

## Lab credentials and connection points

| Component | Lab value (today; rotates) | Where to set it |
|-----------|----------------------------|-----------------|
| NDO | `https://198.18.133.100`, `admin`, dCloud password | `sac-johbarbe-AFRICOM-terraform-nac-ndo/.env`, `aci-ndo/terraform.tfvars`, `aci-ndo-ipv6/terraform.tfvars`, plus `TF_VAR_ndo_password` env var per shell |
| Kelley APIC | `https://198.18.134.252` | `aci-apic/terraform.tfvars` + `TF_VAR_kelley_apic_password` |
| Del-Din APIC | `https://198.18.134.253` | `aci-apic/terraform.tfvars` + `TF_VAR_deldin_apic_password` |
| vCenter | `198.18.134.80`, `administrator`, `C1sco12345!` | `TF_VAR_vcenter_*` env vars only |
| MCP key (per fabric) | generate fresh per session, ≥8 chars mixed | `eval "$(./scripts/generate-mcp-key.sh kelley)"` etc. |

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

- **`HTTP remote state endpoint requires auth`** (or the second-stage
  **`Backend configuration changed`**) in any of the three http-backend
  directories (`sac-johbarbe-AFRICOM-terraform-nac-ndo/`, `aci-ndo/`,
  `aci-ndo-ipv6/`) → canonical 5-step recovery in
  `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/README.md` → "Recovery: stuck on
  backend errors after running `terraform init`". Same sequence works
  in all three directories; the per-stack `README_LAB.md`s cross-link
  to it.
- **`Post "/login": unsupported protocol scheme ""`** → `lab.tfvars` is
  shadowing real credentials with placeholder strings. Each directory's
  `README_LAB.md` covers this.
- **APIC reachable but `terraform plan` fails on `aaaLogin`** → password
  expired, IP changed, or `TF_VAR_*_apic_password` not exported in current
  shell. Run `make auth-check` in `apic-vmware/`.
- **NDO returns "VRF EUR-X must be deployed on Fabric Y before BD …"** →
  Phase 2 was done out of order. Undeploy and redeploy in the table order.
- **`Error: "error in remove for path: '/templates/0/bds/N/subnets/M':
  Unable to access invalid index"`** (one or more lines, on any apply that
  removes >1 BD subnet at once — typical during V1→V2 cut-over or any
  tear-down) → the `mso` provider's well-known array-index race at
  `-parallelism > 1`. The recovery is "re-apply serially", but the exact
  commands differ by stack because `aci-ndo-ipv6/` requires a
  var-file the others don't:

  In `aci-ndo/` (Phase 4, no var-file needed):
  ```
  terraform refresh
  terraform plan -refresh=false -parallelism=3 -out=plan.tfplan
  terraform apply -parallelism=1 plan.tfplan
  ```
  The Makefile exposes the same as `make apply-serial` (or `make apply PARALLELISM=1`).

  In `aci-ndo-ipv6/` (Phase 5, must pass `-var-file=lab.tfvars` —
  omitting it makes the mso provider default to `domain=null, platform=null`
  and the next plan errors out with `HTTP Request failed with status code
  200 after 3 attempts` against lab NDO):
  ```
  terraform refresh -var-file=lab.tfvars
  terraform plan -var-file=lab.tfvars -refresh=false -parallelism=3 -out=plan.tfplan
  terraform apply -parallelism=1 plan.tfplan
  ```
  There is no Makefile here; invoke terraform directly. Use `prod.tfvars`
  instead of `lab.tfvars` at production cutover.

  In `sac-johbarbe-AFRICOM-terraform-nac-ndo/` (Phase 1, no var-file needed): same as
  `aci-ndo/`.

  Full diagnosis + the matching change to `aci-ndo/Makefile`
  in `aci-ndo/README_LAB.md` → "BD subnet remove races".

---

## Production cutover

Production swaps URLs, credentials, and CI jobs (manual triggers, masked
variables, GitLab HTTP state backend). The phase order is the same. The
operational deltas live in:

- `sac-johbarbe-AFRICOM-terraform-nac-ndo/README.md` — production NDO target
- `aci-apic/README.md` — production APIC root (separate
  Terraform state from `apic-vmware/`)
- `docs/REDESIGN.md` "Production cutover runbook" — coordinated UCS /
  vCenter / network-team cutover sequence (separate from the lab build)

---

## What this README deliberately does not cover

- Schema design rationale (2-VRF split, BD/EPG model, ESG plan) →
  `docs/DESIGN.md`.
- GitLab CI/runner setup, masked variables, CI-side workflow →
  `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/README.md`.
- Per-stack troubleshooting catalogs → each stack's own `README.md` /
  `README_LAB.md`.


---

## Publishing to wwwin-github.cisco.com

Real customer IPs live on `main` — only push the `publish` branch externally.
The `publish` branch has all real IPs replaced with RFC1918/ULA equivalents.

All three repos follow the same pattern:

```bash
# Push each repo's publish branch to Cisco internal GitHub (cx-usps-auto org)
git -C ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo \
  push git@wwwin-github.cisco.com:cx-usps-auto/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo.git publish:main

git -C ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo \
  push git@wwwin-github.cisco.com:cx-usps-auto/sac-johbarbe-AFRICOM-terraform-nac-ndo.git publish:main

git -C ~/DC/nxos/sac-johbarbe-AFRICOM-nxos-n5k \
  push git@wwwin-github.cisco.com:cx-usps-auto/sac-johbarbe-AFRICOM-nxos-n5k.git publish:main
```

**Re-syncing after new work on main:**
1. `git checkout publish && git rebase main`
2. Re-run sed substitutions (see `.claude/session-state.md` in each repo for the full map)
3. `git add -A && git commit -m "sanitize: replace real IPs/IPv6 with private/ULA equivalents"`
4. Force-push `publish`

---

## Enabling the NDO Orchestrator App (single-node ND / dCloud)

**Skip this section if your lab NDO is already up and you can `curl /login` against it.** Do this once per fresh dCloud Topology Builder build, before Phase 1 or any Terraform that talks to NDO.

dCloud's "Nexus Dashboard 4.1" image installs **NDFC** and **Insights** automatically; it does **not** install NDO (Orchestration). On a single-node vND, the cluster UI's "Enable Orchestration" toggle hangs on `Enabling / Disabling Orchestration feature is in progress. This may take a while.` indefinitely (1+ hour observed) and never completes. The [Cisco ND 4.1 prerequisites guide](https://www.cisco.com/c/en/us/td/docs/dcn/nd/4x/deployment/cisco-nexus-dashboard-deployment-guide-41x/nd-prerequisites-41x.html) recommends the built-in **swagger** UI to enable Orchestration on single-node lab clusters, but in practice the path it tells you to search for (`/settings/general/actions/enableOrchestration`) is buried in a collapsed sub-menu — and on some 4.1 builds the explicit action endpoint isn't even surfaced in the in-product **swagger**. The reliable path is the underlying `licensetier` API directly.

### Before you start

- **Disable NDFC and Insights** from the ND cluster UI if dCloud auto-started them — NDO won't install while they're co-resident on a single-node vND.
- Confirm the license tier is **Advantage** or **Premier**. Essentials does not include NDO.
- Have an ND admin login (the same one you'll later put in `.env`, `terraform.tfvars`, or `TF_VAR_ndo_password`).

### Enable Orchestration via the `licensetier` API (recommended)

Substitute your real ND host and admin password (the dCloud default for a fresh 4.1 image is often `C1sco12345`):

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

If nothing comes back after 10 minutes, the most common culprits are NDFC/Insights still co-resident on the single-node vND, or `licensetier` was rejected (re-run the step 2 POST and check the response body).

The same login probe you'll use from Terraform also doubles as a smoke test:

```bash
curl -sk -X POST "$ND/login" \
  -H 'Content-Type: application/json' \
  -d "{\"userName\":\"$ND_USER\",\"userPasswd\":\"$ND_PASS\",\"domain\":\"local\"}"
```

A valid response includes a `token` field. Once both the service list shows `cisco-mso` and `/login` returns a token, proceed to Phase 1.

### Optional: enable from the in-product swagger UI

The Cisco docs walk you through this via **swagger**; it's the same outcome via the same `licensetier` plumbing under the hood, just clickier and more menu-spelunky. Use only if you want to keep the runbook fully UI-driven, or if you need to verify the `licensetier` API call did what you expected.

1. From the ND UI: top-right `?` → **Help Center** → **API reference: Swagger (In-product)**.
2. Make sure you're on the **cluster-level swagger** (the URL bar should still be the ND host root, not a service tab like NDFC or Insights).
3. Left nav → **Infra** group → **expand the `System Settings` sub-menu**. This is the gotcha: the sub-menu is collapsed by default and `Ctrl+F` won't find anything inside its body until you click to expand. The docs' "search for `/settings/general/actions/enableOrchestration`" instruction therefore returns no results until then.
4. Find `POST /settings/general/actions/enableOrchestration`.
5. Expand → **Try it Out** → **Execute**.

If you still can't find the endpoint after expanding `System Settings`, the explicit action isn't exposed in your build's **swagger** — fall back to the `licensetier` recipe above.

### ND 4.x UI setup

1. **Admin → System Settings → Advanced Settings** — enable "Display advanced settings and options for TAC support."
2. **Admin → System Status → Features** — disable NDFC and Insights; enable Orchestrator only.
3. **Manage → Fabrics → Create Fabric** — when onboarding: select the **Premier** license tier and **uncheck Telemetry** (leaving Telemetry checked blocks the Orchestrator radio button in the next step).
4. Back at **Manage → Fabrics**, select the fabric → **Actions → Edit Fabric Settings** → select the **Orchestrator** radio button.
5. Access NDO via **Manage → Orchestration**.

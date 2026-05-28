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
    │       ├── nac-aci-aedcg/                 AEDCG fabric-specific YAML
    │       └── nac-aci-aedck/                 AEDCK fabric-specific YAML
    │
    ├── aci-ndo/                               [Phase 4 — IPv4 redesign tenant tree]
    │   ├── README.md                          reference (cutover, schema)
    │   └── data/nac-ndo/                      NDO YAML (AEDCE-V2 schema)
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
| 1 | Build foundational NDO state (tenant `EUR`, schema `AEDCE`, 5 prod templates) | `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/` | ~10 min plan/apply | Terraform |
| 2 | Deploy 5 templates to AEDCG/AEDCK (in strict order) | NDO UI | ~15 min total | **Manual UI** |
| 2.5 | Push legacy N5K static port bindings to AEDCE EPGs | `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/scripts/` | ~2 min | Python (`deploy_bindings_python_v2.py`) |
| 3 | APIC fabric/access policies, MCP, VMware VMM domains | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-apic/` | ~5 min apply | Terraform (both fabrics in one root) |
| 4 | V2 redesign tenant tree (schema `AEDCE-V2`, template `Tenant_EUR_V2`; all tenant-scoped objects suffixed `-V2`) | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo/` | ~5 min apply + UI deploy | Terraform + manual UI |
| 5 *(optional)* | IPv6 RCC layer (adds `AppProf-RCC` to existing `L2_Stretched`) | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo-ipv6/` | ~30 min apply at `-parallelism=3` | Terraform + manual UI re-deploy |
| 6 | Static port bindings (post-deploy push not modeled in NAC YAML) | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/scripts/` | ~2 min | Python + manual UI re-deploy |
| 7 | Verify on APICs and vCenter | APIC GUI + vCenter | as needed | Manual |

Phase 5 is optional **only** if you take Phase 6 Path B (`generate_fi_bindings.py`).
If you take Phase 6 Path A (`dump_bindings.py`), Phase 5 is a hard prerequisite.

---

## Phase 0 — Bootstrap GitLab CI/CD variables *(optional, prerequisite for CI runs only)*

Skip this phase entirely if you plan to run everything from your laptop with `local_override.tf` (the path the rest of this runbook assumes by default).

Read this phase if you want GitLab CI to drive `terraform plan` / `terraform apply` for any of Phases 1, 3, 4, or 5. The GitLab project that hosts each repo needs:

- `sac-johbarbe-AFRICOM-terraform-nac-ndo`: 6 variables — `MSO_URL`, `MSO_USERNAME`, `MSO_PASSWORD` (mask+protect), `MSO_DOMAIN`, `TF_HTTP_USERNAME`, `TF_HTTP_PASSWORD` (mask).
- `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo`: 18 variables — `NDO_*`, `AEDCG_APIC_*`, `AEDCK_APIC_*`, `VCENTER_*`, `TF_HTTP_*` (lab set, with masked/protected flags per project policy). The `_PROD`-suffixed variant for `apic-vmware-prod` is provisioned later via the same script with `--prod` (or on a separate production GitLab) — see the "Production cutover" subsection below.

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

**Pattern B — Same GitLab project hosts both lab and prod CI.** This is what `apic-vmware-prod/.gitlab-ci.yml` is designed for: it reads `AEDCG_APIC_PASSWORD_PROD` (etc.) so both lab and prod APIC variables can coexist on one project. For this pattern, run the lab bootstrap first to populate the 18 lab variables, then re-run the wrapper with `--prod` to add the 8 `_PROD` APIC variables alongside them:

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo
./scripts/setup_gitlab_ci_variables_interactive.sh           # lab pass (one-time, already done in Phase 0 above)
./scripts/setup_gitlab_ci_variables_interactive.sh --prod    # prod cutover: adds AEDCG_*_PROD + AEDCK_*_PROD only
```

`--prod` mode:

- prompts for both production APIC URLs (`AEDCG_APIC_URL_PROD`, `AEDCK_APIC_URL_PROD`), the production APIC admin password, and (silently) generates fresh `AEDCG_MCP_KEY_PROD` / `AEDCK_MCP_KEY_PROD` values
- does **not** touch `NDO_*`, `VCENTER_*`, or `TF_HTTP_*` — those are either shared between lab and prod (the per-project CI files have no `_PROD` variant for them) or already set in the lab pass
- still validates the GitLab PAT length and downgrades any value that can't be masked, exactly like the lab pass

`sac-johbarbe-AFRICOM-terraform-nac-ndo` has no `--prod` mode because its CI file references only `MSO_*` (one NDO instance is targeted at a time). To repoint that project at production NDO on the same GitLab, edit the values directly in `Settings → CI/CD → Variables`, or re-run its bootstrap with the prod block uncommented in `.env`.

> **Don't forget the IPv6 RCC deferred chain at prod cutover.** The lab already has L3Out-RCC-E-G / L3Out-RCC-E-K and their APIC-side OSPF / interface / VLAN-pool entries live (stages 6a / 6b / 6c). Production starts without them. After production Phases 1 → 5 are applied and Phase 6 bindings have been pushed, replay the same three stages against the prod APICs by following `aci-ndo-ipv6/README_LAB.md` → "Deferred — re-enable after bindings" with prod APIC URLs / credentials in `terraform.tfvars`. Order is still NDO → wait for NDO sync → APIC L3Out details → APIC VLAN entries — same chain, prod values.

---

## Phase 1 — Foundational NDO build (`sac-johbarbe-AFRICOM-terraform-nac-ndo`)

This repo creates **tenant `EUR`**, **schema `AEDCE`** with five templates
(`VRF_Template`, `L2_Stretched`, `L2_Non-Stretched`, `G-Specific_Only`,
`K-Specific_Only`), 11 prod VRFs, 266 BDs, 265 EPGs, 13 L3Outs, and 812 VPC
static-port bindings. Phase 4 in `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo/` cross-
references `AEDCE / VRF_Template / Any` (the filter), so this phase has to
land first.

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

## Phase 2.5 — Legacy AEDCE static port bindings (`~/DC/NXOS/n5k/`)

The NAC YAML does not model `staticPorts`, so the 265 EPGs deployed in Phase 2
land on AEDCG and AEDCK with no static port bindings. Phase 2.5 pushes the
legacy N5K bindings (665 VPC static-port bindings across AEDCG nodes 152/153
and AEDCK nodes 119/191) via the NDO REST API.

The input is `terraform.tfvars.json` from the N5K migration toolkit
(`~/DC/NXOS/n5k/`). It is generated by Stage 1 of that toolkit
(`process_all_switches.yml` against the N5K interface/port-channel/VLAN
dumps) and already contains `schema_name: "AEDCE"` and the NDO credentials.
Re-run Stage 1 whenever the switch topology changes before running this step.

```bash
cd ~/DC/NXOS/n5k
source ~/dc_redesign/bin/activate   # needs requests + urllib3

# Lab — dry run first
python3 deploy_bindings_python_v2_lab.py terraform.tfvars.json --dry-run

# Lab — live push
python3 deploy_bindings_python_v2_lab.py terraform.tfvars.json

# Production — dry run (reads credentials from vault.yml via vault_pass.txt)
python3 deploy_bindings_python_v2_prod.py terraform.tfvars.json --dry-run

# Production — live push
python3 deploy_bindings_python_v2_prod.py terraform.tfvars.json
```

For production, `vault.yml` + `vault_pass.txt` must be present in
`~/DC/NXOS/n5k/` and `ndo_host` in `terraform.tfvars.json` must point at the
production NDO. Use `--no-vault` to read the password from the JSON instead.

After the push, re-deploy any AEDCE templates that received new bindings in
the NDO UI so the `staticPorts` reach the APICs. Phase 2.5 is idempotent —
the script skips bindings that already exist on NDO.

---

## Phase 3 — APIC-direct fabric & VMM (`aci-apic/`)

Builds access policies, MCP Instance Policies (per fabric, with per-fabric
keys), the VMware VMM domains `APCG-VDS1` (on AEDCG) and `APCK-VDS1`
(on AEDCK) that Phase 4's EPGs will bind to, the UCS Fabric Interconnect
uplink access policies (Design A): `fi-static-vlan-pool` (213 VLANs),
`phys-fi-domain`, `fi-aaep`, `PC_FI_A`/`PC_FI_B` PC policy groups
(LACP active), and per-leaf interface/switch profiles for leaves 152/153
(AEDCG) and 119/191 (AEDCK); and the legacy IPv4 infrastructure objects:
`VLAN_All_Combined` static pool (5 broad ranges, ~2148 VLANs), `PhysDom_ACI_Nexus`
physical domain, `L3_Dom_ND` routed domain, and `AAEP_ACI_Nexus` (used by all
N5K migration VPC/PC policy groups). Independent of Phase 2 — could technically
run in parallel — but in practice do it after.

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-apic

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
APIC, both registered against vCenter. Additionally on each APIC:
`fi-static-vlan-pool` (static, 213 VLANs), `phys-fi-domain`, `fi-aaep`,
`PC_FI_A` and `PC_FI_B` PC policy groups (LACP active), per-leaf interface
profiles for the FI uplinks (leaf 152 eth1/6 and leaf 153 eth1/7 on AEDCG;
leaf 119 eth1/6 and leaf 191 eth1/7 on AEDCK), and the legacy IPv4 objects:
`VLAN_All_Combined` static pool, `PhysDom_ACI_Nexus`, `L3_Dom_ND`, and
`AAEP_ACI_Nexus`.

> **Plan heads-up (first apply after lab YAML update):** The `vmm-host-ports`
> interface selector in `leaf-152-153-intprof` and `leaf-119-191-intprof` will
> show as a **modify** — port range changes from 1-48 to 8-48. This is expected;
> ports 1-7 are now reserved for FI uplinks (eth1/6-7) and future use.

Details: `aci-apic/README_LAB.md` (lab daily-driver),
`README.md` (env-var table, MCP-key rationale, error catalog).

---

## Phase 4 — V2 (consolidated) tenant tree (`aci-ndo/`)

This is where the cross-schema reference to `AEDCE/VRF_Template/Any` (built
in Phase 1, deployed in Phase 2) actually resolves. Schema `AEDCE-V2`
contains a **single template** `Tenant_EUR_V2` (2 VRFs, 39 BDs, 39 EPGs,
2 ANPs, 2 contracts; all tenant-scoped objects suffixed `-V2` to coexist
with the legacy `AEDCE` schema in tenant `EUR` — see
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
make plan    # expect: 1 schema (AEDCE-V2), 1 template (Tenant_EUR_V2),
             #         2 VRFs (-V2), 39 BDs (-V2), 2 ANPs (-V2),
             #         39 EPGs (-V2), 2 contracts (-V2).
             # NO mso_tenant create (manage_tenants=false; EUR is from Phase 1).
make apply
```

Then NDO UI → **Application Management → Schemas → AEDCE-V2 →
`Tenant_EUR_V2` → Deploy to sites** → AEDCG and AEDCK. **One template here**,
not three (any older docs that say `Tenant_Policy / Stretched_BDs /
App_Profiles` reflect an abandoned design).

After Phase 4: 2 VRFs (`VRF-EUR-V2`, `VRF-DMZ-V2`), 39 BDs, 39 EPGs are live on
AEDCG and AEDCK; each EPG is bound to the per-fabric VMM domain from Phase 3
(`APCG-VDS1` on AEDCG, `APCK-VDS1` on AEDCK), so 39 port-groups should now
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
existing `L2_Stretched` template, **and/or** you intend to use Phase 6
Path A (`dump_bindings.py`) which reads from `AEDCE/AppProf-RCC` to seed
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
#       mso_platform="nd" + vrf_template_name="VRF_Template". Omitting it
#       falls back to the variables.tf defaults (null/null/VRF_Template),
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

Then NDO UI → schema `AEDCE` → template `L2_Stretched` → **Deploy to sites**
again (since this Terraform run added `AppProf-RCC` and 39 IPv6 EPGs into
`L2_Stretched`).

The "Deferred — re-enable after bindings" stages 6a/6b/6c documented in
`aci-ndo-ipv6/README_LAB.md` happen **after** our Phase 6, not before.
**Lab status:** stages 6a/6b/6c are already applied on AEDCG/AEDCK — the
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

# Read AEDCE/AppProf-RCC, write a JSON for AEDCE-V2.
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

Whichever path: finish in **NDO UI → schema AEDCE-V2 → Tenant_EUR_V2 →
Deploy to sites** (re-deploy) so the new `staticPorts[]` push to APIC.

Details: `scripts/README.md` (CLI reference, vault flow, VLAN
strategy rationale).

---

## Phase 7 — Verify

| Where | Check |
|---|---|
| AEDCG APIC GUI — FI uplinks | `Fabric → Access Policies → Pools → VLAN → fi-static-vlan-pool` exists (static, 213 VLANs). `fi-aaep` references both `phys-fi-domain` and `APCG-VDS1`. `Interfaces → Leaf Interfaces → Policy Groups → PC_FI_A` and `PC_FI_B` exist (type PC, LACP active). `Profiles → leaf-152-fi-intprof` and `leaf-153-fi-intprof` exist with `fi-a-uplink`/`fi-b-uplink` selectors on ports eth1/6 and eth1/7 respectively. |
| AEDCK APIC GUI — FI uplinks | Same as AEDCG. `leaf-119-fi-intprof` (port 6) and `leaf-191-fi-intprof` (port 7). |
| AEDCG APIC GUI — legacy objects | `Pools → VLAN → VLAN_All_Combined` exists (static, 5 ranges: 5-54, 66-67, 80-998, 1000-2176, 2205). `Domains → Physical → PhysDom_ACI_Nexus` references `VLAN_All_Combined`. `Domains → L3 → L3_Dom_ND` references `VLAN_All_Combined`. `Global Policies → AEP → AAEP_ACI_Nexus` references both `PhysDom_ACI_Nexus` and `L3_Dom_ND`. |
| AEDCK APIC GUI — legacy objects | Same names and structure as AEDCG — `VLAN_All_Combined`, `PhysDom_ACI_Nexus`, `L3_Dom_ND`, `AAEP_ACI_Nexus`. |
| AEDCG APIC GUI | `Tenants → EUR → Application Profiles → AppProf-NetCentric-V2 / AppProf-DMZ-V2` shows 39 EPGs (36 + 3) |
| AEDCG APIC GUI (ESG layer) | `Tenants → EUR → Application Profiles → AppProf-AppCentric-V2 → Endpoint Security Groups` shows `ESG-All-Internal-V2` (in `VRF-EUR-V2`) and `ESG-All-DMZ-V2` (in `VRF-DMZ-V2`); each ESG's `Operational → Endpoints` lists the same endpoints as the corresponding EPGs sum |
| AEDCK APIC GUI | Same as AEDCG — both NDO ANPs (39 EPGs) and the APIC-direct AppCentric ANP (2 ESGs) |
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
| NDO | `https://198.18.133.100`, `admin`, dCloud password | `sac-johbarbe-AFRICOM-terraform-nac-ndo/.env`, `aci-ndo/terraform.tfvars`, `aci-ndo-ipv6/terraform.tfvars`, plus `TF_VAR_ndo_password` env var per shell |
| AEDCG APIC | `https://198.18.134.252` | `aci-apic/terraform.tfvars` + `TF_VAR_aedcg_apic_password` |
| AEDCK APIC | `https://198.18.134.253` | `aci-apic/terraform.tfvars` + `TF_VAR_aedck_apic_password` |
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

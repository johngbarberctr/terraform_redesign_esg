# Session Handoff — sac-johbarbe-AFRICOM-terraform-esg-nac-ndo
**Last updated:** 2026-06-25
**Session focus (2026-06-25):** `aci-ndo-ipv6` cleanup so its GitLab CI plans clean: L3Out renames, NDO template remap, deferred APIC-direct stages, and a full `RCC` → `AFRICOM`/`AFR-PROD-V6` rebrand of the IPv6 layer. (Companion consolidation work happened in the `nac-ndo` sibling repo — see its own session-state.md.)
**Session focus (2026-06-17 afternoon):** VRF consolidation (11 → 1, placeholder `AFR-PROD`), template rename (5→4) documentation cleanup — all changes in nac-ndo sibling repo.
**Session focus (2026-06-17 morning):** nac-ndo pipeline failure debugging and CI revert — no ESG repo code changes this session.
**Session focus (2026-06-16):** AFRICOM NIPR implementation plan corrections, design review PPTX fixes, Phase 0/1 automation, documentation updates.

---

## What happened this session (2026-06-25) — aci-ndo-ipv6 CI cleanup + RCC→AFRICOM rebrand

All work this session is in **`aci-ndo-ipv6/`** (this repo). Goal: get its GitLab pipeline to plan/validate clean and remove all `RCC` naming from the IPv6 layer. The IPv6 layer is a **separate VRF + contract by design** (kept distinct from the IPv4 `AFR-PROD`), just rebranded.

### Accomplished (committed + pushed to gitlab main)

Commit history this session (newest first):
- `2bacf20` refactor(aci-ndo-ipv6): rebrand RCC objects to AFRICOM/AFR-PROD-V6
- `b7e237b` fix(aci-ndo-ipv6): map RCC templates to actual AFRICOM schema templates
- `187f472` fix(aci-ndo-ipv6): defer APIC-direct L3Out/VLAN stages so CI plans clean
- `b00ac28` refactor(aci-ndo-ipv6): rename RCC L3Outs to site-named -V2 objects

**1. L3Out / ExtEPG site renames** (`l3outs_ndo.tf`, `l3outs_apic.tf.disabled`, all docs):
- `L3Out-RCC-E-G` → `L3Out-Kelley-V2`, `L3Out-RCC-E-K` → `L3Out-Del-Din-V2`
- `ExtEPG-RCC-E-G` → `ExtEPG-Kelley-V2`, `ExtEPG-RCC-E-K` → `ExtEPG-Del-Din-V2`
- `-V2` suffix is REQUIRED: another schema in the same tenant already uses the bare site names, and L3Out names are tenant-unique.

**2. NDO template remap** (`bds_epgs.tf`, `l3outs_ndo.tf`) — the schema templates were renamed/merged, so old names no longer exist:
- `L2_Stretched` AND `L2_Non-Stretched` → `Stretched_Services` (non-stretched was folded into stretched)
- `Site1-Specific_Only` → `Kelley_Unique`, `Site2-Specific_Only` → `Del_Din_Unique`
- hardcoded `"VRF_Template"` → `var.vrf_template_name` (default `"VRF"`)

**3. Deferred APIC-direct stages** (`187f472`): `l3outs_apic.tf` and `vlans_apic.tf` renamed to `*.tf.disabled` via `git mv`. They reference L3Outs that don't exist at plan time (data sources) and broke CI. This matches the documented deferred-deployment design — re-enable them manually after the NDO L3Outs are deployed (README_LAB Stage 6b/6c).

**4. RCC → AFRICOM rebrand** (`2bacf20`, `bds_epgs.tf` + `l3outs_ndo.tf` + 16 docs):
- VRF `VRF-RCC` → `AFR-PROD-V6` (dedicated IPv6 VRF, created in the `VRF` template)
- Contract: `Any_VRF-RCC` + duplicate `Any_RCC` → single `Any_AFR-PROD-V6`
- ANP `AppProf-RCC` → `AppProf-AFR-PROD-V6`
- Services `EPG-RCC-{DNS,SVR,DCO,UNIX}` → `EPG-AFRICOM-*`; `BD-RCC-*` → `BD-AFRICOM-*`

**5. Duplicate cleanup** (root cause of the earlier `Duplicate Resource` error, from the non-stretched→stretched merge):
- Deleted duplicate `Any_RCC` contract + its 2 vzAny provider/consumer bindings
- Deleted duplicate ANP `appprof_rcc_non_stretched` + its 2 site-ANP associations; repointed the affected site EPGs to `appprof_rcc_stretched`
- Repointed L3Out ExtEPG contract relationships to `contract_vrf_rcc`

**Validation:** `terraform fmt` clean; `terraform validate` → "Success! The configuration is valid." (Note: validate/plan must run OUTSIDE the local sandbox — the MSO/ACI provider plugin fails the go-plugin handshake under sandboxing.)

### Decisions made this session and why

| Decision | Rationale |
|----------|-----------|
| IPv6 stays a SEPARATE VRF (`AFR-PROD-V6`) + contract (`Any_AFR-PROD-V6`), not merged into IPv4 `AFR-PROD` | User initially asked to fold into `AFR-PROD`, then corrected: the IPv6 config must be its own VRF (and therefore its own contract). |
| New names are `AFR-PROD-V6` / `Any_AFR-PROD-V6` / `AppProf-AFR-PROD-V6`, services `EPG-AFRICOM-*` | User wanted zero `RCC` and chose these names. |
| Kept internal HCL resource labels (`vrf_rcc`, `bd_rcc_dns`, `appprof_rcc_stretched`, …) unchanged | These are local Terraform identifiers, never pushed to ACI. Renaming ~280 of them is pure churn/risk with no functional effect. |
| Left historical `RCC-E` project/branding text + meeting/presentation narrative ("RCC Services", "RCC-E IPv6 Infrastructure") and the separate `terraform-nac-ndo` repo's `RCC` untouched | `RCC` there is the separate real customer / project branding, not the deployed ACI object names. |
| `*.tf.disabled` for APIC-direct files | Established repo convention for deferred stages; keeps CI planning only the NDO layer. |

### Do NOT repeat next session (this repo)

- **`aci-ndo-ipv6/` is NO LONGER "keep as-is".** The older handoff said don't touch it — that's now superseded. This session intentionally rebranded it. The IPv6 ACI object names are now `AFR-PROD-V6` / `AppProf-AFR-PROD-V6` / `EPG-AFRICOM-*` / `BD-AFRICOM-*` / `L3Out-{Kelley,Del-Din}-V2`. Do not reintroduce `RCC` object names.
- **Do not re-enable `l3outs_apic.tf.disabled` / `vlans_apic.tf.disabled` in CI** until the NDO L3Outs (`L3Out-Kelley-V2` / `L3Out-Del-Din-V2`) are actually deployed — their data sources will fail at plan time otherwise.
- **Do not rename the internal `*_rcc` HCL resource labels** — intentionally left as-is.
- **Run terraform plan/validate outside the sandbox** — the provider plugin can't start under sandboxing (handshake failure, not a config error).

### Next concrete step (this repo)

`AFR-PROD-V6` is a NEW VRF name (was `VRF-RCC`), so the next apply will **create** it, not rename in place. Before/after running the `aci-ndo-ipv6` pipeline: if a stale `VRF-RCC` (and `Any_VRF-RCC` / `AppProf-RCC` / old `EPG-RCC-*` BDs) already exist in the NDO `AFRICOM`/`VRF` template from a prior run, delete them so you don't end up with both old and new objects. Then run the `aci-ndo-ipv6` pipeline and confirm a clean plan/apply.

---

## What happened this session (2026-06-17 afternoon) — VRF consolidation

All substantive work is in `sac-johbarbe-AFRICOM-terraform-nac-ndo`. Summary:

**11 VRFs → 1 VRF (`AFR-PROD`, placeholder)** in `data/ndo/schema_AFRICOM.nac.yaml`:
- 9 VRF definitions in `VRF` template collapsed to single `AFR-PROD`
- 10 vzAny contracts (`Any_EUR-*`) collapsed to single `Any_AFR-PROD`
- 287 BD/L3Out `vrf: name:` references updated to `AFR-PROD`
- Kelley Unique's 2 site-local VRFs removed
- ExtEPG contract bindings updated to `Any_AFR-PROD`
- `README.md` VRF count table corrected (11 VRFs → 1)

**⚠️ `AFR-PROD` is a placeholder name.** Once the customer confirms the actual production VRF name, do a global replace of `AFR-PROD` in the schema file.

---

## What happened this session (2026-06-17 morning) — no ESG code changes

All work this session was in the sibling repo `sac-johbarbe-AFRICOM-terraform-nac-ndo`.

**Summary:** The nac-ndo pipeline failed after the tenant rename (EUR → AFR-DEL.Services) because NDO
and Terraform state got out of sync during the first failed run. Debugging led to adding unnecessary
CI changes (parallelism=1, two-pass apply) which were reverted. The correct fix is a clean-slate
reset of both NDO and GitLab state, then running the unmodified original CI.

**See `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/.claude/session-state.md`** for the full
detail including the required cleanup steps before the pipeline can succeed.

**This repo (ESG) is unaffected.** The nac-ndo pipeline must succeed (and templates deployed in NDO)
before any ESG repo pipelines should be run.

---

## What was accomplished last session (2026-06-16 afternoon)

### 1. AFRICOM_ACI_Design_Review.pptx — corrections applied

Key corrections across slides 3, 6, 7, 8, 12, 14, 15:
- VRF count corrected: **1 stretched VRF** (not 9). Slide 3, 6, 8 all updated.
- "VRF is in a shared stretched template" → clarified as the **current problem state** that the redesign is meant to resolve (the VRF lives in the Stretched VRF template, which is correct, but the issue is that the Stretched BD template also exists and needs cleanup).
- Tenant `EUR` removed everywhere — AFRICOM tenant is `AFR-DEL.Services`.
- "Phase 3" on slide 10 and "Step 1" on slide 12 clarified with context from the implementation plan.

### 2. AFRICOM_Implementation_Plan.md — two corrections

- Line 1119: `EUR` → `AFR-DEL.Services`
- Line ~1479: VRF count corrected from 2 to 1 (+ conditional DMZ VRF)

### 3. AFRICOM_Implementation_Plan.docx — created

Converted `AFRICOM_Implementation_Plan.md` to Word format using `python-docx` in a temp venv.
Output: `docs/AFRICOM/AFRICOM_Implementation_Plan.docx`

### 4. Phase 0 automation — `scripts/validate_fabric.py` (NEW, untracked)

Comprehensive read-only health check + optional Phase 0 write actions. Uses only stdlib (no pip install needed).

**Read-only checks:**
- APIC cluster health on both Kelley and Del Din
- Fault counts by severity
- EPG / BD / VRF counts for `AFR-DEL.Services` tenant
- BGP peer states + per-VRF prefix counts
- VMM domain controller connectivity
- Remote EP Learning status
- NDO connectivity + schema listing

**Optional write actions (require --phase0 or individual flags):**
- `--snapshot` — trigger APIC config snapshot on both sites (polls for completion)
- `--backup-ndo` — trigger NDO backup to configured remote location (graceful fallback if no remote configured)
- `--export-schema` — download full AFRICOM NIPR schema JSON to `--artifacts-dir`
- `--compare <file>` — drift detection against a saved baseline

**CLI quick reference:**
```bash
# Full Phase 0 pre-change:
python3 scripts/validate_fabric.py --phase0 --artifacts-dir scripts/baseline/pre-phase1 --label pre-phase1

# Read-only health check:
python3 scripts/validate_fabric.py -o scripts/baseline/quick-check.json

# Post-change drift report:
python3 scripts/validate_fabric.py --compare scripts/baseline/pre-phase1/baseline.json
```

### 5. Phase 1 NAC YAML files — created (gitignored, under africom-aci-apic/)

Three files implementing Phase 1 fabric/system settings:

| File | Contents |
|------|----------|
| `africom-aci-apic/data/nac-aci-shared/phase1-fabric-settings.nac.yaml` | Disable Remote EP Learning; BFD on fabric-facing interfaces (both sites) |
| `africom-aci-apic/data/nac-aci-kelley/phase1-kelley-settings.nac.yaml` | Enable Port Tracking (Kelley only) |
| `africom-aci-apic/data/nac-aci-deldin/phase1-deldin-settings.nac.yaml` | Enable Rogue EP Control (Del Din only) |

### 6. GitLab CI pipeline — `africom-aci-apic/.gitlab-ci.yml` created (gitignored)

Defines `validate`, `plan`, `deploy` stages for lab + prod:
- `phase0-validate-africom` — runs `scripts/validate_fabric.py`. Set `PHASE0_FULL=true` in the Run Pipeline dialog to enable write actions (snapshots, backups, schema export) during a change window.
- `phase1-plan-africom` — `terraform plan` for Phase 1 NAC YAML changes.
- `phase1-apply-africom` — `terraform apply`, `when: manual`. Runs post-apply validation + drift comparison.

Root `.gitlab-ci.yml` updated to `include` the new pipeline file.

### 7. Documentation updates

| File | What changed |
|------|-------------|
| `PROJECT_MAP.md` | Corrected stale paths; added "Mac — Key File Locations" table; added "AFRICOM NIPR Implementation Plan — Automation Map" table linking plan steps to files; updated CI variables section |
| `PROJECTS_LISTING.md` | Expanded ESG repo entry; added nac-ndo repo entry; fixed naming and descriptions throughout |
| `africom-aci-apic/README.md` | Added "AFRICOM NIPR Implementation Plan — automation" section: what's automated, what's manual and why, validate_fabric.py usage |
| `scripts/README.md` | Added script index table; added `validate_fabric.py` section with full flag reference and credential env vars; clarified distinction from `africom-aci-apic/scripts/` |

---

## What is still in progress

### Committed and pushed this session (ESG repo)

Commit `6989b2a` pushed to gitlab main:
- `scripts/validate_fabric.py` (new) — Phase 0 health check / write actions
- `.gitlab-ci.yml` — includes africom-aci-apic pipeline + tenant rename
- `PROJECT_MAP.md`, `PROJECTS_LISTING.md`, `README.md`, `README_LAB.md`, `scripts/README.md` — docs + tenant rename
- `scripts/dump_bindings.py`, `generate_ipv6_bindings1.py`, `generate_ipv6_bindings2.py`, `get_epg_endpoints.py` — tenant rename

**Gitignored new content** (will NOT appear in git status, must be committed separately when ready to promote out of staging):
- `africom-aci-apic/.gitlab-ci.yml`
- `africom-aci-apic/data/nac-aci-shared/phase1-fabric-settings.nac.yaml`
- `africom-aci-apic/data/nac-aci-kelley/phase1-kelley-settings.nac.yaml`
- `africom-aci-apic/data/nac-aci-deldin/phase1-deldin-settings.nac.yaml`
- `docs/AFRICOM/AFRICOM_Implementation_Plan.docx`

### Implementation plan — not yet run against production

The Phase 0 script and Phase 1 NAC YAML files exist on disk but have never been executed against the real Kelley/Del Din fabric. All CI jobs have `when: manual` or are blocked by missing credentials.

---

## Decisions made this session and why

| Decision | Rationale |
|----------|-----------|
| `validate_fabric.py` stays in `scripts/` (repo root), NOT in `africom-aci-apic/scripts/` | `africom-aci-apic/scripts/` contains Terraform shell helpers (`render-vmm-yaml.sh`, `auth-check.sh`). `scripts/` (repo root) contains standalone Python operational tools. `validate_fabric.py` is Python, talks to NDO as well as two APICs, and runs independently of Terraform. Moving it would be the wrong abstraction. |
| `validate_fabric.py` uses stdlib only (no pip) | CI containers may not have the same Python environment. urllib.request + json are always available. |
| Write actions off by default, enabled via `--phase0` or `PHASE0_FULL=true` | Health checks are safe to run anytime; snapshots/backups/schema export are change-window actions that should not happen on every pipeline run. |
| Phase 1 NAC YAML split into shared + site-specific files | BFD and Remote EP Learning apply to both sites; Port Tracking and Rogue EP Control are site-specific. Shared file avoids duplication; site files allow independent rollout. |
| `africom-aci-apic/` remains gitignored in ESG repo | Staging area — not yet ready for production CI. Will be promoted to its own GitLab project or have the gitignore entry removed when the Terraform state/remote backend is configured. |

---

## Do NOT repeat next session

- **Do NOT add `-parallelism=N` or two-pass applies to nac-ndo CI** without first confirming the original CI is broken. These changes were added in haste on 2026-06-17 and made things worse. They were reverted in commit `c4c1750` in nac-ndo. The original single-apply CI works from a clean slate.
- **`validate_fabric.py` location is settled.** It lives in `scripts/` at the repo root. Do not move it to `africom-aci-apic/scripts/` — that directory is for Terraform shell helpers only.
- **`africom-aci-apic/` and `africom-aci-ndo/` are gitignored.** Do not add them to a commit from this repo. They are staging directories. They need their own GitLab project or gitignore removal before they can be committed.
- **Do NOT set `manage_schemas = true`** in `africom-aci-ndo/main.tf` before populating BD/EPG stubs from the NDO schema export. Running `terraform apply` with empty schema YAML and `manage_schemas = true` will DELETE production BDs/EPGs in NDO.
- **The Site1/Site2 → Kelley/Del-Din rename is COMPLETE** in all tracked files. Do not reintroduce site1/site2 in any new content.
- **Tenant rename `EUR` → `AFR-DEL.Services` is COMPLETE** across all AFRICOM files in both nac-ndo and ESG repos. Do not reintroduce `EUR` as a tenant name in any AFRICOM file. VRF/EPG/object names (`EUR-AIM`, `EUR-E`, `Any_EUR-*`, `Tenant_EUR_V2`, etc.) are intentionally unchanged — those are actual ACI object names.
- **Do not use tenant `EUR`** in AFRICOM context. AFRICOM tenant is `AFR-DEL.Services`.
- **Do not use RCC-E ESG zone names** (ESG-AIM, ESG-AIS, etc.) or VRF names (VRF-AFR-DEL.Services-V2) in AFRICOM context.
- **Do not modify `aci-apic/`, `aci-ndo/`** — preserved RCC-E working state. (NOTE: `aci-ndo-ipv6/` was INTENTIONALLY rebranded on 2026-06-25 — see top section. It is no longer "keep as-is".)
- **`docs/AFRICOM/AFRICOM_Implementation_Plan.docx`** is a binary file in a gitignored path. Do not regenerate it unless the .md changes — conversion requires a temp venv with `python-docx`.

---

## Next concrete steps (in order)

### Step 0 — BLOCKED: fix nac-ndo pipeline first

The nac-ndo pipeline must succeed before any ESG pipelines run. See:
`~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/.claude/session-state.md`

Required before proceeding:
1. Delete `AFRICOM` schema and `AFR-DEL.Services` tenant from NDO UI
2. Delete `ndo-terraform-nac-prod` GitLab state (project 5, Settings → CI/CD → Terraform states)
3. Run nac-ndo pipeline → confirm 1478 resources created
4. Deploy templates in NDO UI in strict order (VRF → Stretched Services → Kelley Unique → Del Din Unique)

### Step 0b — Commit this session's tracked ESG changes (from 2026-06-16)

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo
git add .gitlab-ci.yml PROJECT_MAP.md PROJECTS_LISTING.md README.md \
    scripts/README.md scripts/validate_fabric.py .claude/session-state.md
git commit -m "feat(africom): Phase 0 validation script + Phase 1 CI pipeline + docs

- scripts/validate_fabric.py: APIC/NDO health checks, snapshots, NDO backup,
  schema export, drift detection (stdlib only, no pip required)
- .gitlab-ci.yml: include africom-aci-apic pipeline
- PROJECT_MAP.md: AFRICOM NIPR automation map, corrected paths, CI vars
- PROJECTS_LISTING.md: expanded ESG + nac-ndo repo entries
- scripts/README.md: script index, validate_fabric.py CLI reference"
git push gitlab main
```

### Step 1 — Wire up credentials in GitLab CI

Before any CI job can run, add these masked variables to the GitLab ESG project (Settings → CI/CD → Variables):
```
KELLEY_APIC_URL        https://<kelley-apic>
KELLEY_APIC_USERNAME   admin
KELLEY_APIC_PASSWORD   <masked>
DELDIN_APIC_URL        https://<deldin-apic>
DELDIN_APIC_USERNAME   admin
DELDIN_APIC_PASSWORD   <masked>
NDO_URL                https://<ndo>
NDO_USERNAME           admin
NDO_PASSWORD           <masked>
```

### Step 2 — Run Phase 0 (pre-change validation + baseline)

In the GitLab pipeline, trigger `phase0-validate-africom` with `PHASE0_FULL=true` to:
1. Snapshot both APICs
2. Back up NDO
3. Export AFRICOM NIPR schema JSON (this is the critical artifact — use it to populate BD/EPG stubs in step 4)
4. Save health baseline JSON

Or run locally:
```bash
python3 scripts/validate_fabric.py --phase0 --artifacts-dir scripts/baseline/pre-phase1 --label pre-phase1
```

### Step 3 — Run Phase 1 (fabric settings via CI)

Trigger `phase1-plan-africom` in GitLab → review plan output → manually trigger `phase1-apply-africom`. This applies BFD, Remote EP Learning disable, Port Tracking (Kelley), Rogue EP Control (Del Din).

### Step 4 — Populate BD/EPG stubs from schema export

Use the `AFRICOM NIPR` schema JSON from Step 2 (or download manually: NDO → Application Management → Schemas → AFRICOM NIPR → Download Schema) to populate:
- `africom-aci-ndo/data/nac-ndo/schema-africom-nipr.nac.yaml` — all BD/EPG names, subnets, VLANs, contracts, template assignments
- `africom-aci-apic/data/nac-aci-kelley*/access-policies.nac.yaml` — VLAN pool ranges, VMM domain names (`TODO-VMM-DOMAIN-*` placeholders), port assignments

### Step 5 — Confirm VMM domain names

```bash
moquery -c vmmDomP   # on each APIC
```
Replace `TODO-VMM-DOMAIN-KEL` and `TODO-VMM-DOMAIN-DEL` in access-policies files.

### Step 6 — Set `manage_schemas = true` in africom-aci-ndo/main.tf

Only after Step 4 is complete. Run `terraform plan -parallelism=3` and review carefully before applying.

### Step 7 — vzAny removal (prerequisite for ESG)

Per implementation plan Phase 2:
1. Remove EPG-level Permit-Any contract from all EPGs (can be scripted via APIC REST)
2. Remove vzAny provider+consumer from VRF `AFR-DEL.Services` (Stretched VRF template in NDO)
3. Apply NDO changes + deploy templates
4. Then populate ESG stubs in `africom-aci-apic/data/nac-aci-shared/tenant-afrdel-esgs.nac.yaml`

### Step 8 — NDO template consolidation (Phase 5 — mostly manual)

7 templates → 5 templates requires "Move to Template" in NDO UI (no REST API). See `docs/AFRICOM/AFRICOM_Implementation_Plan.md` Phase 5 for the step-by-step. This cannot be automated.

---

## Confirmed AFRICOM NIPR Facts (authoritative, current)

### Environment
| Item | Value |
|------|-------|
| ACI version | 6.0(9e) |
| ND version | 3.2.2(m) |
| NDO version | 4.4.3 |
| Sites | **Kelley (NADE02) and Del Din (NAIT03) only** — Site B NOT included |
| Tenant | `AFR-DEL.Services` |
| VRF | `AFR-DEL.Services` (same name as tenant) — **1 stretched VRF, not 9** |
| NDO Schema | `AFRICOM NIPR` |
| DHCP policy | `AFRICOM-DHCP_Policy` |

### NDO Schema — AFRICOM NIPR (current: 7 templates)
| Template | Sites |
|----------|-------|
| Stretched VRF | Kelley + Del Din |
| Stretched Bridge Domains | Kelley + Del Din |
| Stretched EPGs | Kelley + Del Din |
| Stretched Non-L2 | Kelley + Del Din |
| Kelley Unique | Kelley only |
| Del Din Unique | Del Din only |
| Site B Unique | **DO NOT USE — Site B excluded** |

Future target (CX recommendation): 5 templates — Stretched VRF / Stretched Services / Del Din Unique / Kelley Unique / (Site B Unique if ever needed).

### BD Counts (March 2026, AFR-DEL.Services only)
| Site | L2 | L3 | Total |
|------|----|----|-------|
| Kelley | 3 | 29 | 32 |
| Del Din | 1 | 27 | 28 |

All L3 BDs: hardware proxy, unicast routing enabled, host-based routing enabled on stretched L3 BDs.

### Tenants
| Tenant | Purpose |
|--------|---------|
| `AFR-DEL.Services` | Production NIPR operational tenant |
| `666 (PALE)` | Sandbox/test tenant — **not managed by this repo** |
| `common` | Built-in |
| `dcnm-default-tn` | Built-in |

### L3Outs (AFR-DEL.Services)
- Named `Kelley` and `Del Din` — simple site-name L3Outs
- Each has Site-to-Site connectivity for L3Out failover

### L3Outs (666 tenant — not our concern)
- `Dev_L3Out-AFR.KEL-Services`
- `Dev_L3Out-AFR.KEL-VDI`
- `Dev_L3Out-AFR.DEL-Services`

### vzAny
- Configured provider+consumer on the VRF — effectively unenforced
- Must be removed before transitioning to application-centric/ESG mode
- An EPG-level "Permit-Any" contract is also applied as a transition measure — both must be cleaned up together

### Node Naming
| Site | Role | Nodes |
|------|------|-------|
| Kelley | APIC | NADE02NMP90, NADE02NMP91, NADE02NMP92 |
| Kelley | Spine | NADE02SP201, NADE02SP202 |
| Kelley | Leaf | NADE02LF101, NADE02LF102 |
| Del Din | APIC | NAIT03NMP90, NAIT03NMP91, NAIT03NMP92 |
| Del Din | Spine | NAIT03SP201, NAIT03SP202 |
| Del Din | Leaf | NAIT03LF101, NAIT03LF102 |
| Del Din | Border Leaf | NAIT03BL103, NAIT03BL104 |

### Infrastructure VLANs (NIPR)
| Site | Infra VLAN |
|------|-----------|
| Kelley | 3967 |
| Del Din | 450 |

### VPC Policies
- Kelley: `AFR-KEL.L101L102-VPC-FW1`
- Del Din SIPR: `AFR-DEL.L103L104-vPC-FW1`

### Backup Policies
- Kelley APIC: 8hr interval local + remote to NADE02NMV07 (Mon & Fri)
- Del Din APIC: 8hr interval local + remote to NADE02NMV07 (no schedule set)

### Open Issues (from CX documents — confirm before acting)
| Issue | Impact |
|-------|--------|
| vzAny provider+consumer | Must remove before ESG work has value |
| EPG-level Permit-Any contract | Must remove alongside vzAny |
| L3Out redundancy (666 tenant L3Outs on single node) | Low |
| NDO schema template consolidation (7→5 templates) | Medium |
| BD subnets — multiple subnets per BD in some cases | Medium |
| VMM integration instability | High — prerequisite for Phase 7 ESG |
| Rogue EP Control not enabled at Del Din | Low (Phase 1 YAML addresses this) |
| AlgoSec installed at both sites | Must deactivate before any ACI upgrade |
| NTP faults at Kelley | Low |

---

## Repo Structure (authoritative)

```
aci-apic/           RCC-E APIC-direct — KEEP AS-IS (hard-won working state)
aci-ndo/            RCC-E NDO V2 redesign — KEEP AS-IS
aci-ndo-ipv6/       IPv6 layer — REBRANDED to AFRICOM/AFR-PROD-V6 on 2026-06-25 (no longer keep-as-is)
africom-aci-apic/   AFRICOM APIC-direct — GITIGNORED staging dir (see below)
africom-aci-ndo/    AFRICOM NDO — GITIGNORED staging dir
docs/AFRICOM/       AFRICOM CX deliverables + design docs
scripts/            Standalone Python operational tools (NOT Terraform helpers)
```

**`africom-aci-apic/scripts/`** = Terraform shell helpers (`render-vmm-yaml.sh`, etc.) called during terraform plan/apply — NOT the same as `scripts/`.

**Do not modify `aci-apic/`, `aci-ndo/` — these are preserved RCC-E work.** (`aci-ndo-ipv6/` was rebranded 2026-06-25 — see top section.)

---

## What is still TODO in africom dirs

| Item | Blocking on | File(s) to update |
|------|-------------|-------------------|
| BD/EPG names and VLANs | NDO schema export (AFRICOM NIPR → Download Schema) | `africom-aci-ndo/data/nac-ndo/schema-africom-nipr.nac.yaml` |
| Subnet ranges per BD | APIC `moquery -c fvBD` | same schema file |
| Contract and filter names | NDO schema export | same schema file (Stretched VRF template) |
| VLAN pool ranges (exact VLANs in use) | APIC or NDO export | `africom-aci-apic/data/nac-aci-kelley*/access-policies.nac.yaml` + deldin |
| VMM domain names | APIC `moquery -c vmmDomP` | both access-policies files (replace `TODO-VMM-DOMAIN-*`) |
| Port assignments / FI uplinks | APIC LLDP neighbors / port descriptions | access-policies files (leaf_interface_profiles) |
| ESG definitions | After BD/EPG catalog confirmed + vzAny removed | `africom-aci-apic/data/nac-aci-shared/tenant-afrdel-esgs.nac.yaml` |
| `manage_schemas = true` | After BD/EPG stubs populated | `africom-aci-ndo/main.tf` line 67 |

---

## Key credentials / IDs (lab only)

| Item | Value |
|------|-------|
| GitLab nac-ndo project ID | 5 |
| GitLab ESG project ID | 3 |
| Root user PAT (api scope) | `glpat-gAyPY9az7ywD73y8jefUGm86MQp1OjUH.01.0w0rj3q95` |
| Project bot PAT (ESG only) | `glpat-zwXHVjIBlmb48eW7XGVvdW86MQp1OjYH...` |

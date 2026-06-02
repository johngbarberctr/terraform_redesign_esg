# Session Handoff — AFRICOM ACI Terraform Projects
**Last updated:** 2026-06-02
**Covers:** ESG monorepo (`sac-johbarbe-AFRICOM-terraform-esg-nac-ndo`) and sibling repos

---

## Repo layout (current, authoritative)

```
~/DC/ACI/
├── sac-johbarbe-AFRICOM-terraform-nac-ndo/    ← Phase 1 (foundational NDO)
└── sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/ ← Phases 3–6 (ESG monorepo)
    ├── aci-apic/                              APIC fabric/VMM (Site1 + Site2, lab + prod)
    ├── aci-ndo/                               V2 tenant redesign (AFRICOM-V2 schema)
    ├── aci-ndo-ipv6/                          IPv6 RCC layer
    ├── scripts/                               FI binding tools
    └── docs/                                  DESIGN.md, REDESIGN.md, strategy docs

~/DC/NXOS/
└── sac-johbarbe-AFRICOM-nxos-n5k/             N5K → ACI migration toolkit
```

---

## What was accomplished this session (2026-06-02)

### 1. All three publish branches pushed to wwwin-github.cisco.com

All three repos are now live under the `cx-usps-auto` org at wwwin-github.cisco.com:

- **sac-johbarbe-AFRICOM-terraform-esg-nac-ndo** — pushed; warning about `aci-ndo-ipv6/terraform_debug.log` (64 MB, in old git history, not currently tracked, already gitignored). Pushed fine, not a blocker.
- **sac-johbarbe-AFRICOM-terraform-nac-ndo** — pushed clean.
- **sac-johbarbe-AFRICOM-nxos-n5k** — pushed; Dependabot flagged 14 vulnerabilities (6 high, 6 moderate, 2 low) in Python deps. Not urgent.

Reuse these commands to push after future `publish` branch updates:
```bash
git -C ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo \
  push git@wwwin-github.cisco.com:cx-usps-auto/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo.git publish:main
git -C ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo \
  push git@wwwin-github.cisco.com:cx-usps-auto/sac-johbarbe-AFRICOM-terraform-nac-ndo.git publish:main
git -C ~/DC/NXOS/sac-johbarbe-AFRICOM-nxos-n5k \
  push git@wwwin-github.cisco.com:cx-usps-auto/sac-johbarbe-AFRICOM-nxos-n5k.git publish:main
```

### 2. ND Orchestrator enablement section added to all four README_LAB.md files

Added "Enabling the NDO Orchestrator App (single-node ND / dCloud)" to:
- `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/README_LAB.md`
- `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo-ipv6/README_LAB.md`
- `sac-johbarbe-AFRICOM-terraform-nac-ndo/README_LAB.md`
- `sac-johbarbe-AFRICOM-nxos-n5k/docs/README_LAB.md`

Section covers: token → `POST /api/v1/licensetier` with `"licenseTier": "Premier"` + `"apps": ["cisco-mso"]`; then full ND 4.x UI sequence (Advanced Settings → Features → Create Fabric with Premier tier + **uncheck Telemetry** → Edit Fabric Settings → Orchestrator radio button → Manage → Orchestration).

Committed to `main` on all three repos, cherry-picked to `publish`, and pushed to wwwin-github.

---

## What was accomplished in the prior session (2026-05-31)

### 1. Naming convention refactoring — completed

All files across both ACI repos updated:

| Old | New |
|---|---|
| `AEDCE` (schema) | `AFRICOM` |
| `AEDCE-V2` | `AFRICOM-V2` |
| `AEDCG` (site name) | `Site1` |
| `AEDCK` (site name) | `Site2` |
| `G-Specific_Only` (template) | `Site1-Specific_Only` |
| `K-Specific_Only` (template) | `Site2-Specific_Only` |
| `AEDCG-SPINE-201` | `Site1-SPINE-201` |
| `AEDCK-SPINE-201` | `Site2-SPINE-201` |
| Leaf node IDs 152/153 (Site1) | 101/102 |
| Leaf node IDs 119/191 (Site2) | 101/102 |
| `nac-aci-aedcg*/` directories | `nac-aci-site1*/` |
| `nac-aci-aedck*/` directories | `nac-aci-site2*/` |
| `schema_AEDCE.nac.yaml` | `schema_AFRICOM.nac.yaml` |
| `schema-aedce-v2.nac.yaml` | `schema-africom-v2.nac.yaml` |

Key detail: `moved {}` blocks in `aci-apic/main.tf` that reference old Terraform state
addresses (`module.aci_aedcg`, `aci_rest_managed.mcp_inst_pol_aedcg`, etc.) have been
**removed entirely** because the new lab has empty state. Those blocks caused an
"Ambiguous move statements" error (two sources → one destination) on a clean state.

### 2. State files — action taken

The old `aci-apic/terraform.tfstate` tracked resources under `module.aci_aedck` /
`provider.aci.aedck` — incompatible with renamed code. User archived it:
```
mv terraform.tfstate terraform.tfstate.old-lab.snap
```
All four modules (aci-apic, aci-ndo, aci-ndo-ipv6, nac-ndo) now start with clean state.

### 3. aci-apic Makefile — TFVARS_FILE added

`make plan` was failing because the Makefile passed no `-var-file` and Terraform
couldn't find `terraform.tfvars` (it doesn't exist — the lab uses `lab.tfvars`).

**Fix:** Added `TFVARS_FILE ?= lab.tfvars` to the Makefile. Every `plan`, `validate`,
and `destroy` target now passes `-var-file=$(TFVARS_FILE)`.

- Default (lab): `make plan` — uses `lab.tfvars`
- Prod override: `make plan TFVARS_FILE=prod.tfvars`

### 4. moved {} blocks removed from aci-apic/main.tf

All `moved {}` blocks were deleted. They served the previous lab's state migration
(monolithic `module.aci` → `module.aci_aedcg` → `module.aci_site1` chain). With
fresh empty state they caused a hard error and are not needed.

**If old state ever needs to be migrated to new names:** The migration chain was:
`module.aci` → `module.aci_aedcg` → `module.aci_site1` (same for site2). This would
require two chained `moved {}` blocks rather than parallel blocks pointing to the
same destination.

### 5. Phase 2.5 description corrected

README incorrectly stated "NAC YAML does not model staticPorts — EPGs land with no
bindings." This contradicts Phase 1 which deploys 812 VPC static-port bindings.

**Corrected:** Phase 2.5 is the N5K → ACI leaf physical replacement process (remove
N5K, install new ACI leaf, configure APIC fabric via toolkit Stage 3, push updated
bindings via Python script Stage 2). Old N5K bindings stay in place until all
switches are replaced (TODO noted in README).

### 6. README updates across all three repos

- `README_LAB.md` (ESG): `make init` added to Phase 3; Phase 3 "no venv needed"
  callout added; old leaf profile names in Phase 7 verify table fixed
  (`leaf-152/153/119/191-fi-intprof` → `leaf-101/102-fi-intprof`);
  Phase 6 `--leaves` arg fixed (`152,153,119,191` → `101,102,101,102`);
  Phase 2.5 rewritten; old N5K path `~/DC/NXOS/n5k` updated to full repo name.
- `aci-apic/README.md`: "no venv needed" note; workflow updated to use `lab.tfvars`;
  fixed `VARS_FILE` → `TFVARS_FILE`; removed stale `terraform.tfvars` copy step.
- `aci-apic/Makefile`: header comment updated to document `TFVARS_FILE` override.
- `docs/DESIGN.md`: directory tree updated (`terraform.tfvars` → `lab.tfvars`/`prod.tfvars`).
- N5K `docs/README_LAB.md`: `AEDCG`/`AEDCK` → `Site1`/`Site2`; old path updated.

---

## Current state — what's working

| Component | Status |
|---|---|
| `sac-johbarbe-AFRICOM-terraform-nac-ndo` | `make plan` runs (MSO_URL set in .env); state archived |
| `aci-apic/` | `make init` done; `make plan` runs with `lab.tfvars`; state archived |
| `aci-ndo/` | State archived; not yet tested this session |
| `aci-ndo-ipv6/` | State archived; not yet tested this session |
| Naming conventions | 100% clean across all tracked files |
| GitLab CI variables | Bootstrap script ran but got HTTP 401 — not yet completed |

---

## Decisions made and why

| Decision | Rationale |
|---|---|
| Remove `moved {}` blocks | Fresh empty state — migration blocks cause "ambiguous move" error; no old state to migrate |
| `TFVARS_FILE ?= lab.tfvars` in Makefile | `lab.tfvars` is the committed lab file; `terraform.tfvars` doesn't exist in this repo structure |
| Do NOT rename ACI objects (VRFs, BDs, EPGs) yet | AFRICOM is the customer — wait for architecture discovery to define object names; framework is generic enough to demo as-is |
| Keep old N5K bindings in NDO during leaf replacement | Remove only after all switches are replaced and new bindings confirmed — noted as TODO |
| Old `terraform.tfstate` → `.old-lab.snap` (not deleted) | Preserve for reference; new lab starts fresh |

---

## Do NOT repeat next session

- **Do not add `moved {}` blocks back** — they were removed intentionally for fresh state.
  If migrating from an old state in the future, the correct chain is two sequential
  blocks, not parallel blocks to the same destination.
- **Do not create `terraform.tfvars` in `aci-apic/`** — the Makefile now uses `lab.tfvars`
  by default. The `terraform.tfvars.example` is reference-only.
- **Do not change `aci.aedck` back in providers.tf** — the alias is now `aci.site2`.
  The old state that referenced `aci.aedck` has been archived.

---

## GitLab CI variable bootstrap — INCOMPLETE

The `setup_gitlab_ci_variables_interactive.sh` script failed with HTTP 401. The PAT
provided did not have `api` scope or Maintainer role on the project. This means:
- GitLab CI pipeline cannot run `terraform plan/apply` yet
- State backend (`TF_HTTP_PASSWORD`) is not configured in CI
- All work this session was done via local `make` commands

**To fix next session:**
1. Generate a new PAT at `http://localhost:8080/-/user_settings/personal_access_tokens`
   with scope `api` and Maintainer role on both projects.
2. `source .env` first so the script picks up `MSO_URL` etc.
3. Re-run: `./scripts/setup_gitlab_ci_variables_interactive.sh` in each repo.
4. Enter the full GitLab URL with `http://` when prompted.

---

## Next concrete steps (in order)

1. **Fix GitLab CI bootstrap** (see above) — prerequisite for pipeline runs.
2. **`aci-apic/` first apply** against the new lab:
   ```bash
   cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-apic
   source scripts/set-apic-password.sh
   eval "$(./scripts/generate-mcp-key.sh site1)"
   eval "$(./scripts/generate-mcp-key.sh site2)"
   export TF_VAR_vcenter_hostname_ip='198.18.134.80'
   export TF_VAR_vcenter_datacenter='Datacenter'
   export TF_VAR_vcenter_username='administrator'
   export TF_VAR_vcenter_password='C1sco12345!'
   export TF_VAR_vcenter_dvs_version='unmanaged'
   make auth-check
   make plan
   make apply
   ```
3. **Phase 1 (nac-ndo) apply** — `source .env && terraform plan && terraform apply` in
   `sac-johbarbe-AFRICOM-terraform-nac-ndo/`.
4. **Phase 2 (NDO UI deploy)** — deploy AFRICOM templates in strict order per README.
5. **Verify APIC GUI** per Phase 7 table in README_LAB.md.

---

## Pending TODOs (from previous sessions, still open)

- ~~Push `publish` branches to `cx-usps-auto` org on wwwin-github.cisco.com~~ — **done 2026-06-02**
- Add legacy objects (`VLAN_All_Combined`, `PhysDom_ACI_Nexus`, `L3_Dom_ND`, `AAEP_ACI_Nexus`)
  to prod YAML (`nac-aci-site1-prod/` and `nac-aci-site2-prod/access-policies.nac.yaml`)
- Regenerate `fi_bindings.json` with `--vlan-map fi_vlan_map.json` for AFRICOM-V2 static bindings
- Gather Site1 interface data (current `terraform.tfvars.json` entries are for Site2/AEDCK only)
- Determine VPC_D3A-B port assignment on leaves 101/102 at Site1
- Apply "must be unique" fix to `scripts/deploy_bindings_python_v2_prod.py`
- Remove old N5K static port bindings from NDO after all N5Ks are replaced (deferred)
- Verify `aci-ndo-ipv6` state key in GitLab and migrate if `ndo-terraform-ipv6` slot is non-empty

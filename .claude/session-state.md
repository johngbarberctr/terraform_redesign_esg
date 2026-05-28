# Session Handoff — AFRICOM ACI Terraform Projects
**Date:** 2026-05-28
**Covers:** Both repos — see "Repo layout" below

---

## Repo layout (current, authoritative)

```
~/DC/ACI/
├── sac-johbarbe-AFRICOM-terraform-nac-ndo/    ← Phase 1 (foundational NDO)
│   ├── main.tf                                single-root: tenant EUR, schema AEDCE, 5 templates
│   ├── data/ndo/                              ndo.nac.yaml, defaults.yaml, schema_AEDCE.nac.yaml
│   └── scripts/                              deploy_bindings_python_v2.py, patch_nodes.py, etc.
│
└── sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/ ← Phases 3–6 (ESG monorepo)
    ├── aci-apic/                              APIC fabric/VMM (AEDCG + AEDCK, lab + prod)
    ├── aci-ndo/                               V2 tenant redesign (AEDCE-V2 schema)
    ├── aci-ndo-ipv6/                          IPv6 RCC layer (AppProf-RCC → AEDCE/L2_Stretched)
    ├── scripts/                               FI binding tools (generate, deploy, parity-check)
    └── docs/                                  DESIGN.md, REDESIGN.md, strategy docs
```

## Git remotes (current)

| Repo | Remote | URL |
|---|---|---|
| `sac-johbarbe-AFRICOM-terraform-nac-ndo` | origin | `ssh://git@host.containers.internal:2222/root/sac-johbarbe-AFRICOM-terraform-nac-ndo.git` |
| `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo` | gitlab | `http://localhost:8080/root/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo.git` |
| `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo` | origin | `git@github.com:johngbarberctr/terraform_redesign_esg.git` (GitHub — import deferred) |

GitLab is at `http://localhost:8080`. Admin: `root` / `cisco123` (macOS keychain, host=localhost).
OAuth token for API: use `curl -sf -X POST "http://localhost:8080/oauth/token" -d "grant_type=password&username=root&password=cisco123"` — expires in 2h, refresh as needed.

---

## What was accomplished this session

### 1. ESG repo restructure — completed

The `aci-redesign/` flat layout has been replaced with a per-project directory structure.

```
Old → New
aci-redesign/apic-vmware/     → aci-apic/         (also absorbed apic-vmware-prod/)
aci-redesign/ndo/             → aci-ndo/
ndo-terraform-ipv6/           → aci-ndo-ipv6/
aci-redesign/scripts/         → scripts/
aci-redesign/{DESIGN,README*} → docs/
```

`aci-redesign/` directory has been removed.

Key code changes made during restructure:
- `aci-apic/main.tf`: `yaml_directories` → `"./data/..."` (was `"../data/..."`); `manage_tenants = var.manage_tenants`
- `aci-apic/variables.tf`: added `manage_tenants` variable (bool, default false)
- `aci-apic/scripts/render-vmm-yaml.sh`: `${MODULE_DIR}/data/` (was `${MODULE_DIR}/../data/`)
- `aci-apic/Makefile`: rendered paths → `./data/nac-aci-*-rendered/`
- `aci-apic/.gitlab-ci.yml`: merged lab + prod CI; lab uses `lab.tfvars` + `TF_VAR_manage_tenants=true`; prod uses `prod.tfvars` + `TF_VAR_manage_tenants=false`
- `aci-ndo/main.tf`: `yaml_directories = ["./data/nac-ndo"]`
- `aci-ndo-ipv6/.gitlab-ci.yml`: `ndo-terraform-ipv6` → `aci-ndo-ipv6` **everywhere including the state key** (see warning below)
- Root `.gitlab-ci.yml`: now includes 3 sub-project files; parity-check-fi-bindings `cd scripts`
- New files: `aci-apic/README.md`, `aci-ndo/README.md`, `aci-apic/lab.tfvars`, `aci-apic/prod.tfvars`

### 2. Both repos renamed — completed

| Old name | New name |
|---|---|
| `terraform-esg/` | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/` |
| `ndo-terraform-nac-prod/` | `sac-johbarbe-AFRICOM-terraform-nac-ndo/` |

Both GitLab projects renamed via API. Both local directories renamed. Both git remotes updated. All cross-references in all files updated in both repos.

### 3. README files — completed

- `README_LAB.md` (ESG root): all stale `aci-redesign/`, `terraform-esg`, `ndo-terraform-nac-prod` refs updated; directory tree reflects new structure
- `aci-apic/README.md`: new — data layout, lab/prod tfvars, CI job table, key variables
- `aci-ndo/README.md`: new — prerequisites, data layout, local workflow, CI job table, module flags
- `ndo-terraform-nac-ndo/README.md` and `README_LAB.md`: all cross-references updated to new repo names and new ESG sub-project paths

---

## Decisions made and why

| Decision | Rationale |
|---|---|
| State key `ndo-terraform-nac-prod` preserved in ndo `.gitlab-ci.yml` TF_HTTP_ADDRESS | Live state exists in GitLab under that key. Renaming the key creates an empty state; migration required before rename. |
| State key `aci-redesign` (lab) and `aci-redesign-prod` (prod) preserved in `aci-apic/.gitlab-ci.yml` | Same reason — live state. |
| State key `aci-redesign-ndo` preserved in `aci-ndo/.gitlab-ci.yml` | Same reason. |
| `manage_tenants` as a variable in `aci-apic/` (not two separate roots) | Single directory; `lab.tfvars` sets true (tenant may not exist), `prod.tfvars` sets false. CI sets via `TF_VAR_manage_tenants`. |
| GitLab project rename via OAuth password grant | `root/cisco123` stored in macOS keychain; PAT not available; OAuth grant works on self-hosted GitLab CE. |
| LACP active (not mac-pinning) for PC_FI_A/B | User explicitly stated — do not re-debate. |
| fi-aaep carries VMM domain AND phys-fi-domain | User confirmed — needed for legacy IPv4 interfaces. |
| `VLAN_All_Combined` pool name | Aligns with aci-ndo-ipv6 stack naming; user confirmed. |
| Archive whole repos to `~/DC/archive/ACI/` (not `_archive/`) | Whole repos go to top-level archive; `_archive/` is for within-repo file archiving. |

---

## WARNING: aci-ndo-ipv6 state key changed

During the restructure, `replace_all=true` was used on `aci-ndo-ipv6/.gitlab-ci.yml` which changed the Terraform state key from `ndo-terraform-ipv6` to `aci-ndo-ipv6` in `TF_HTTP_ADDRESS`. Unlike the other stacks where state keys were explicitly preserved, this one was changed.

**Impact:** If live state exists in GitLab under `ndo-terraform-ipv6`, the CI pipeline will see an empty plan after this change (it will try to re-create everything). Local laptop runs using `terraform.tfstate` in `aci-ndo-ipv6/` are unaffected.

**Verify before next CI run:**
1. Check GitLab → Infrastructure → Terraform States for the ESG project
2. If `ndo-terraform-ipv6` state slot exists and is non-empty, migrate it:
   ```bash
   # Push local state to the new key
   terraform init \
     -backend-config="address=http://localhost:8080/api/v4/projects/<id>/terraform/state/aci-ndo-ipv6" \
     -backend-config="username=gitlab-ci-token" \
     -backend-config="password=<PAT>" \
     -migrate-state -force-copy
   ```

---

## What has NOT been applied yet

All YAML and Terraform changes are written. **No `terraform plan` or `terraform apply` has been run against the restructured directories.**

Before running plan in `aci-apic/`, `terraform init` is required because the module source path changed (`.terraform/` was built against the old `../data/` path):

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-apic
terraform init         # required after directory restructure
make render            # regenerate VMM domain YAML in data/nac-aci-*-rendered/
make auth-check        # confirm APIC IPs/creds in terraform.tfvars
make plan              # expect CREATEs + one vmm-host-ports MODIFY
make apply
```

Expected plan for aci-apic (lab):
- **CREATE:** `VLAN_All_Combined`, `PhysDom_ACI_Nexus`, `L3_Dom_ND`, `AAEP_ACI_Nexus`, `fi-static-vlan-pool`, `phys-fi-domain`, `lacp-active`, `fi-aaep`, `PC_FI_A`, `PC_FI_B`, per-leaf interface profiles (4), per-leaf switch profiles (4)
- **MODIFY:** `vmm-host-ports` port range 1–48 → 8–48 (expected, not a problem)
- **DESTROY:** nothing

---

## Prod YAML — not yet updated

Legacy objects still need to be added to the prod data directories:
- `aci-apic/data/nac-aci-aedcg-prod/access-policies.nac.yaml`
- `aci-apic/data/nac-aci-aedck-prod/access-policies.nac.yaml`

Objects to add: `VLAN_All_Combined`, `PhysDom_ACI_Nexus`, `L3_Dom_ND`, `AAEP_ACI_Nexus`.

These exist on prod APIC already (per 2024-03-08 backup). Adding takes ownership of pre-existing objects; first plan will show drift — accept it.

---

## Pending work from earlier sessions

- Regenerate `fi_bindings.json` with `--vlan-map fi_vlan_map.json` for AEDCE-V2 static bindings (Phase 6 Path B)
- AEDCG interface data: all 47 entries in `terraform.tfvars.json` are AEDCK; needs switch dumps from APCG-D1A, D2A, etc.
- VPC_D3A-B port assignment on leaves 152/153 — port unknown, excluded from `configure_apic_fabric_lab.yml`
- FEX 123/128 on AEDCK leaf 153 — verify dual-use of node ID 153
- Apply "must be unique" fix to `scripts/deploy_bindings_python_v2_prod.py` (same fix already in lab version)

---

## Do NOT repeat next session

- Do not re-read APIC backup files for legacy object names:
  - Pool: `VLAN_All_Combined`, PhysDom: `PhysDom_ACI_Nexus`, L3Dom: `L3_Dom_ND`, AAEP: `AAEP_ACI_Nexus`
  - Backup files: `~/Downloads/DocExchange(1)/ce2_AEDCG-APIC_backup-2024-03-08T01-50-40.tar.gz` and `ce2_AEDCK-APIC-backup-2024-03-08T01-50-18.tar.gz`
- Do not re-debate LACP vs mac-pinning for FI uplinks — LACP active is correct for lab
- Do not re-debate fi-aaep needing phys-fi-domain — it does
- Do not re-debate archive location — whole repos go to `~/DC/archive/ACI/`
- Do not re-plan the directory restructure — it is complete
- Do not re-plan the repo renames — both are complete (local + GitLab)
- GitHub rename for ESG repo is deferred — user will import from GitLab when ready; `origin` remote still points to the old GitHub repo name `terraform_redesign_esg`
- `aci-ndo-ipv6` state key was intentionally changed (see WARNING section above) — do not change it back; verify migration if needed

---

## Next concrete steps (in order)

1. **Verify aci-ndo-ipv6 state key** — check GitLab Terraform states for the ESG project; migrate if `ndo-terraform-ipv6` slot is non-empty
2. **Run lab APIC apply:**
   ```bash
   cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-apic
   terraform init
   make render
   make auth-check
   make plan
   make apply
   ```
3. **Verify in APIC GUI** — per Phase 7 table in `README_LAB.md`
4. **Prod YAML update** — add legacy objects to `nac-aci-aedcg-prod/` and `nac-aci-aedck-prod/`

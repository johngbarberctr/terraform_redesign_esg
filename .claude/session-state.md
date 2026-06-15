# Session Handoff — sac-johbarbe-AFRICOM-terraform-esg-nac-ndo
**Last updated:** 2026-06-10
**Session focus (2026-06-10):** Complete AFRICOM directory framework update (ndo + apic roots)

---

## What was accomplished this session (2026-06-10)

### 1. africom-aci-ndo fully updated
- `main.tf` — comments rewritten for AFR-DEL.Services, `manage_schemas = false` (SAFETY default)
- `data/nac-ndo/tenant.nac.yaml` — rewritten for AFR-DEL.Services tenant stub
- `data/nac-ndo/schema-africom-v2.nac.yaml` — DELETED (RCC-E EUR V2 content)
- `data/nac-ndo/schema-africom-nipr.nac.yaml` — NEW: AFRICOM NIPR 6-template structure
  (Stretched VRF, Stretched BD, Stretched EPG, Stretched Non-L2, Kelley Unique, Del Din Unique)
  with TODO stubs throughout pending NDO schema export
- `.gitlab-ci.yml` — rewritten: state key `africom-aci-ndo`, job names `africom-ndo-*`, paths updated
- `README.md` — rewritten for AFRICOM NIPR

### 2. africom-aci-apic fully updated
- `main.tf` — data dir refs updated (site1→kelley, site2→deldin), comments updated for AFR-DEL.Services
- `data/nac-aci-site1/` → renamed to `data/nac-aci-kelley/`
- `data/nac-aci-site2/` → renamed to `data/nac-aci-deldin/`
- `data/nac-aci-site1-prod/` → renamed to `data/nac-aci-kelley-prod/`
- `data/nac-aci-site2-prod/` → renamed to `data/nac-aci-deldin-prod/`
- `data/nac-aci-shared/tenant-eur-esgs.nac.yaml` → renamed and rewritten as `tenant-afrdel-esgs.nac.yaml`
  (AFR-DEL.Services stub with ESG stubs pending vzAny removal)
- `data/nac-aci-kelley/access-policies.nac.yaml` — rewritten for NADE02LF101/102, AFRICOM stubs
- `data/nac-aci-deldin/access-policies.nac.yaml` — rewritten for NAIT03LF101/102/BL103/104, AFRICOM stubs
- `data/nac-aci-kelley-prod/access-policies.nac.yaml` — rewritten for AFRICOM Kelley prod
- `data/nac-aci-deldin-prod/access-policies.nac.yaml` — rewritten for AFRICOM Del Din prod
- `data/nac-aci-shared/README.md` — updated for AFRICOM
- `.gitlab-ci.yml` — rewritten: state keys `africom-aci-apic`/`africom-aci-apic-prod`, job names `africom-apic-*`, paths updated
- `README.md` — rewritten for AFRICOM NIPR

### Result
Both `africom-aci-apic/` and `africom-aci-ndo/` are now fully AFRICOM-specific with zero stale RCC-E references.
The framework is safe to plan (no-op with manage_schemas=false) but cannot apply until TODO stubs are populated.

### What was accomplished last session (2026-06-09)
Document review (5 CX docs), initial AFRICOM directory scaffolding (rsync copy of aci-apic/ and aci-ndo/).

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
| VRF | `AFR-DEL.Services` (same name as tenant) |
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
| Rogue EP Control not enabled at Del Din | Low |
| AlgoSec installed at both sites | Must deactivate before any ACI upgrade |
| NTP faults at Kelley | Low |

---

## Repo Structure (after this session)

```
aci-apic/           RCC-E APIC-direct — KEEP AS-IS (hard-won working state)
aci-ndo/            RCC-E NDO V2 redesign — KEEP AS-IS
aci-ndo-ipv6/       RCC-E IPv6 — KEEP AS-IS
africom-aci-apic/   AFRICOM APIC-direct — NEW (copy of aci-apic, AFRICOM content)
africom-aci-ndo/    AFRICOM NDO — NEW (copy of aci-ndo, AFRICOM content)
docs/AFRICOM/       AFRICOM CX deliverables + design docs
```

**Do not modify aci-apic/, aci-ndo/, aci-ndo-ipv6/ — these are preserved RCC-E work.**

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

## What was accomplished last session (2026-06-08)

### nac-ndo Phase 1 pipeline — now PASSING ✅
All work was in `sac-johbarbe-AFRICOM-terraform-nac-ndo`. Summary:
- **Renamed Site1 → Kelley, Site2 → Del-Din** across all data YAML, schema YAML, scripts, CI comments.
- **Cleared stale GitLab Terraform state** (`ndo-terraform-nac-prod`, project ID 5).
- **Set `manage_system = false`** in `main.tf`.
- **Root user PAT confirmed working:** `glpat-gAyPY9az7ywD73y8jefUGm86MQp1OjUH.01.0w0rj3q95`
- **Templates are NOT yet deployed** to Kelley/Del-Din APIC. `deploy_templates = false` in main.tf.

---

## Decisions made and why

| Decision | Rationale |
|----------|-----------|
| `manage_schemas = false` in africom-aci-ndo/main.tf | **Safety**: schema YAML stubs are not yet populated. Setting true with an empty/partial schema YAML would cause Terraform to DELETE existing production BDs/EPGs from the AFRICOM NIPR schema in NDO. Only flip to true AFTER all BD/EPG stubs are populated from NDO schema export. |
| Site B excluded from all AFRICOM Terraform | User confirmed: two sites only (Kelley, Del Din) |
| Preserve aci-apic/, aci-ndo/, aci-ndo-ipv6/ unchanged | Hard-won RCC-E working state; may be needed again |
| africom dirs copy RCC-E logic/structure | Same module versions, same provider pattern, same CI structure — only content changes |
| BD/EPG catalog left as stubs | Cannot populate without NDO schema export |
| Do not manage 666 (PALE) tenant | Sandbox tenant — out of scope |
| Deleted schema-africom-v2.nac.yaml from africom-aci-ndo | That file contained RCC-E EUR V2 content (VRF-EUR-V2, 39 RCC-E BDs) — not AFRICOM production data. Replaced with schema-africom-nipr.nac.yaml. |

---

## Do NOT repeat next session

- **Do NOT set `manage_schemas = true`** in `africom-aci-ndo/main.tf` before populating BD/EPG stubs from the NDO schema export. Running `terraform apply` with an empty schema YAML and `manage_schemas = true` will delete production BDs/EPGs from the AFRICOM NIPR schema in NDO.
- **Do not include Site B** in any AFRICOM Terraform. Two sites only: Kelley and Del Din.
- **Do not modify aci-apic/, aci-ndo/, aci-ndo-ipv6/** — these are preserved RCC-E files.
- **Do not use VRF-EUR-V2, VRF-DMZ-V2** in AFRICOM context — those are RCC-E V2 redesign VRFs. AFRICOM VRF is `AFR-DEL.Services`.
- **Do not use EUR tenant** in AFRICOM context. AFRICOM tenant is `AFR-DEL.Services`.
- **Do not use RCC-E ESG zone names** (ESG-AIM, ESG-AIS, etc.) in AFRICOM context.
- **schema-africom-v2.nac.yaml no longer exists** — it was deleted because it contained RCC-E EUR V2 content. The AFRICOM schema file is now `schema-africom-nipr.nac.yaml`.
- **vlans_apic.tf VLAN map (3001–3500)** is RCC-E IPv6, not AFRICOM.

---

## Next concrete steps (in order)

1. **Pull NDO schema export**: Application Management → Schemas → AFRICOM NIPR → Download Schema (JSON).
   Unblocks BD/EPG/contract/filter population in africom-aci-ndo.

2. **Populate BD/EPG stubs** in `africom-aci-ndo/data/nac-ndo/schema-africom-nipr.nac.yaml` from schema export.
   Map each template's BDs/EPGs into the appropriate template section.

3. **Populate VLAN pools** in kelley and deldin access-policies files (`moquery -c fvnsEncapBlk`).

4. **Confirm VMM domain names** and replace `TODO-VMM-DOMAIN-*` placeholders.
   Command: `moquery -c vmmDomP` on each APIC.

5. **Set `manage_schemas = true`** in `africom-aci-ndo/main.tf` (line 67) after step 2 is complete.
   Run `terraform plan -parallelism=3` and review carefully before applying.

6. **vzAny removal** (prerequisite for meaningful ESG policy):
   - Remove EPG-level Permit-Any contract from all EPGs
   - Remove vzAny provider+consumer from VRF AFR-DEL.Services in Stretched VRF template
   - Apply NDO changes + deploy templates
   - Then populate ESG stubs in `tenant-afrdel-esgs.nac.yaml`

7. **Deploy nac-ndo templates in NDO UI** (RCC-E sac-johbarbe-AFRICOM-terraform-nac-ndo work, still pending from prior session):
   - `VRF_Template` → Kelley, then Del-Din
   - `L2_Stretched` → Kelley, then Del-Din
   - `L2_Non-Stretched` → Kelley, then Del-Din
   - `Kelley-Specific_Only` → Kelley only
   - `Del-Din-Specific_Only` → Del-Din only

---

## Key credentials / IDs (lab only)

| Item | Value |
|------|-------|
| GitLab nac-ndo project ID | 5 |
| GitLab ESG project ID | 3 |
| Root user PAT (api scope) | `glpat-gAyPY9az7ywD73y8jefUGm86MQp1OjUH.01.0w0rj3q95` |
| Project bot PAT (ESG only) | `glpat-zwXHVjIBlmb48eW7XGVvdW86MQp1OjYH...` |

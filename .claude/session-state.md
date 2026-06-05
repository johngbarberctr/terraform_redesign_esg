# Session Handoff — sac-johbarbe-AFRICOM-terraform-esg-nac-ndo
**Last updated:** 2026-06-03
**Session focus:** AFRICOM NIPR design review — adapting this repo for a new customer engagement

---

## What was accomplished this session (2026-06-03)

### 1. Full design review against AFRICOM CX documents
Both official Cisco CX deliverables were read in full:
- `docs/AFRICOM/AFRICOM-NIPR-ACI_Optimization_Final.docx` (Sept 2025, v2.0)
- `docs/AFRICOM/AFRICOM-NIPR-DC_Resiliency.docx` (March 2026, v1.1)

Key findings extracted, prioritized, and mapped to the redesign.

### 2. Scope clarification — this repo vs AFRICOM
The current Terraform was built for the **RCC-E EUR tenant**, not AFRICOM's `AFR-DEL.Services` tenant. The **structure** (two-root split, nac-aci + nac-ndo, ESG APIC-direct, phased migration model) transfers cleanly. The **content** (tenant name, schema name, VRF/BD/EPG names, BD catalog, VLAN ranges) does not and must be rebuilt for AFRICOM.

AFRICOM-specific facts confirmed this session:
- **2 sites only**: Kelley (NADE02) and Del Din (NAIT03). Site B is decommissioned — remove all Site B references.
- **Tenant**: `AFR-DEL.Services`
- **Current fabric state**: ACI 6.0(9e), ND 3.2.2(m), NDO 4.4.3 — already on target versions
- **APIC fabric already configured**: access policies, VLAN pools, AAEP, leaf profiles, MCP are all live. The `apic-vmware/` Terraform root is not needed for AFRICOM.
- **MCP already deployed**: do not re-apply the MCP Instance Policy pattern. It exists on the production fabric.
- **Scale**: ~32 BDs, ~56 EPGs, 9 VRFs — much smaller than RCC-E's 215/266/11. BD mapping is a spreadsheet afternoon, not a project.
- **vzAny in provider+consumer mode**: effectively unenforced. The Permit-Any EPG contract was added on top as a transition measure. Both must be addressed before ESG segmentation has any value.
- **VMM integration**: multiple VDS offline at time of last CX assessment. Credentials expired, management IP on ACI-managed VDS (circular failure). Must be stabilized before Phase 7 ESG work.

### 3. Documents created (all in docs/AFRICOM/)
- **`AFRICOM_ACI_Design_Review.pptx`** — 15-slide deck, AFRICOM-only content. No RCC-E/EUR references. Script: `docs/build_africom_design_pptx.py`.
- **`AFRICOM_Implementation_Plan.md`** — Full phased implementation plan covering Phases 0–7 with detailed steps, verification checklists, rollback procedures, per-step outage risk tables (Appendix D), and plain-English explanations of what each change does (Appendix E).

---

## Decisions made and why

| Decision | Rationale |
|---|---|
| Work through CX optimization/resiliency findings (Phases 0–6) before starting the ACI redesign (Phase 7) | Routing asymmetry, VMM instability, and schema disorder are prerequisites for a reliable redesign deploy. Building on a broken foundation creates compounding problems. |
| `apic-vmware/` Terraform root not needed for AFRICOM | APIC fabric (access policies, VLAN pools, VMM domain, MCP) is already configured in production. Deploying this root would risk overwriting live config. |
| MCP Instance Policy pattern not applicable to AFRICOM | Already deployed with a production key. The pattern exists in this repo because RCC-E was building from scratch. AFRICOM is not. |
| ESG scope remains NDO-layer + APIC-direct (no change to two-root split) | `nac-ndo ~> 1.2.0` still has no ESG resource. ESG layer still rides `nac-aci@0.7.0` APIC-direct. Same constraint applies to AFRICOM as to RCC-E. |
| VRF consolidation target left open (do not assume 2 VRFs) | Unknown whether the 9 VRFs carry overlapping IP space. Any overlap blocks consolidation regardless of design intent. Must audit before committing to a VRF count. |
| 4-template NDO schema target | CX recommendation from Resiliency doc: VRF / Stretched-Services / Kelley-Unique / DelDin-Unique. NDO 4.x auto-restructured the existing schema to 7 templates — consolidating to 4 is Phase 5 of the implementation plan. |
| Site B removed from all documents and scripts | Site B has been decommissioned. Removed from pptx, removed from implementation plan. |
| Do not use RCC-E zone names (ESG-AIM, ESG-AIS, etc.) | These were based on EUR tenant VRF names (EUR-AIM, EUR-AIS, etc.) which are RCC-E-specific. AFRICOM's zone taxonomy is unknown and must be defined by the customer team. |

---

## Do NOT repeat next session

- **Do not use ESG-AIM, ESG-AIS, ESG-AIV, ESG-AIZ, ESG-AIG, ESG-AIP, ESG-DMZ-Web** or any EUR/RCC-E zone names in AFRICOM context. These were removed from all AFRICOM documents. AFRICOM's zone ESG names must come from the customer's own security zone taxonomy.
- **Do not reference Site B** (NADJ prefix). It is decommissioned. Two sites only: Kelley and Del Din.
- **Do not plan to deploy `apic-vmware/` against AFRICOM production**. The fabric is already configured. Touching it risks overwriting live policy.
- **Do not create `terraform.tfvars` in `aci-apic/`** — still applies from prior session. Makefile uses `lab.tfvars` by default.
- **Do not add `moved {}` blocks back** to `aci-apic/main.tf` — removed intentionally, fresh state.
- **Do not conflate RCC-E content (tenant EUR, VRF-EUR-V2, BD-AD-V2, AppProf-NetCentric-V2) with AFRICOM content (tenant AFR-DEL.Services)**. The naming conventions in this repo's YAML files are RCC-E specific. AFRICOM needs new YAML files.

---

## What is still in progress / not yet started

| Item | Status | Blocking on |
|---|---|---|
| AFRICOM NDO schema YAML | Not started | VRF audit (must know target VRF count/names first) |
| AFRICOM BD/EPG functional mapping | Not started | VRF audit + AFRICOM team confirmation |
| Phase 0 pre-change snapshots | Not started | Customer engagement kickoff |
| Phase 3 firewall BGP fix | Not started | Firewall team coordination |
| Phase 4 VMM stabilization | Not started | vCenter team coordination |
| Phase 5 template restructuring | Not started | NDO maintenance window |
| GitLab CI variable bootstrap | Still broken | PAT with `api` scope + Maintainer role needed (see below) |

### GitLab CI — still incomplete (carried from prior session)
`setup_gitlab_ci_variables_interactive.sh` failed with HTTP 401. To fix:
1. Generate new PAT at `http://localhost:8080/-/user_settings/personal_access_tokens` with scope `api` and Maintainer role on the project.
2. `source .env` first.
3. Re-run `./scripts/setup_gitlab_ci_variables_interactive.sh` in each repo.
4. Enter the full GitLab URL with `http://` when prompted.

---

## Next concrete steps (in order)

1. **Pull the AFRICOM NIPR NDO schema export** — `Application Management → Schemas → AFRICOM NIPR → Download Schema`. Read the VRF names. This single action answers: why 9 VRFs, what are they called, and whether consolidation is safe.

2. **Check IP overlap across the 9 VRFs** — run `show ip route vrf <name> summary` on each border leaf for all VRFs. Any two VRFs sharing a prefix cannot be merged.

3. **Verify NDI license status** — `ND: Infrastructure → License Management`. Needed for Phase 7A (Application Dependency Mapping before contract authoring).

4. **Begin Phase 0 of the implementation plan** — pre-change snapshots on both Kelley and Del Din APICs + NDO backup. Zero risk, prerequisite for everything else.

5. **Start Phase 1 fabric health changes** — all low-risk APIC settings (Rogue EP Control on Del Din, Port Tracking on Kelley, BFD, FISAC, Remote EP Learning). No maintenance window required.

6. **Begin new AFRICOM-specific Terraform YAML** — once VRF target is known, write `data/nac-ndo/schema-africom-v2.nac.yaml` with `AFR-DEL.Services` tenant, correct VRF names, and BD/EPG catalog mapped from the AFRICOM NIPR schema. Rename schema to `AFR-SERVICES-V2`.

---

## Pending TODOs (from previous sessions, still open)

- ~~Push `publish` branches to `cx-usps-auto` org on wwwin-github.cisco.com~~ — done 2026-06-02
- Add legacy objects (`VLAN_All_Combined`, `PhysDom_ACI_Nexus`, `L3_Dom_ND`, `AAEP_ACI_Nexus`) to prod YAML in `nac-aci-site1-prod/` and `nac-aci-site2-prod/` — still open (RCC-E work)
- Regenerate `fi_bindings.json` with `--vlan-map fi_vlan_map.json` — still open (RCC-E work)
- Gather Site1 interface data for RCC-E (current `terraform.tfvars.json` entries are for Site2 only) — still open
- Apply "must be unique" fix to `scripts/deploy_bindings_python_v2_prod.py` — still open
- Verify `aci-ndo-ipv6` state key in GitLab — still open

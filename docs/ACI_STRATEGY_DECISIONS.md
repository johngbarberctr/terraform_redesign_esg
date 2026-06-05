# ACI V2 Redesign — Strategy & Decisions

**Audience:** RCC-E DC team, with WWT and Cisco as reviewers.

**Purpose:** A single document the team reads together and uses to lock in design decisions. Each item lists current state, a recommendation with the source backing it, open questions for the team, the risk if undecided, and a slot to write the decision.

**Scope (in):** tenant `EUR` V2 redesign — VRFs, BDs, EPGs, ESGs, contracts, vzAny, V2 L3Out ownership, VMM, MCP, access policies, NDO orchestration, naming conventions, application discovery, automation governance.

**Scope (out, intentional):** firewall PBR / L4-L7 service graphs, K8s, AI fabrics, mainframe connectivity, F5 placement, FW migration, OSPF→BGP review, multi-site failover.

**How to use:**
1. Read **Today** + **Recommendation** + **Source** for each item.
2. Answer the **Open questions**.
3. Write the answer in **Decision**.
4. If you defer, fill in **Re-visit** with a date.

**Source legend:**

| Tag | File |
|---|---|
| **BRKDCN** | `docs/presentations/BRKDCN-2984.pdf` |
| **WWT-Long** | `docs/ACI Design Discussion WWT.md` |
| **WWT-Short** | `docs/Design_Discussion_WWT.md` |
| **Sharman** | `docs/Design3_Sharman_Belete.md` |
| **NextGen** | `docs/meeting_summary_next_gen_data_center.md` |
| **Belete-Strategy** | `docs/ACI Network Design and Migration Strategy.md` |
| **DESIGN** | `aci-redesign/DESIGN.md` |
| **OVERVIEW** | `aci-redesign/REDESIGN_OVERVIEW.md` |
| **Schema-V2** | `aci-redesign/data/nac-ndo/schema-africom-v2.nac.yaml` |
| **ESGs-V2** | `aci-redesign/data/nac-aci-shared/tenant-eur-esgs.nac.yaml` |
| **AFRICOM-legacy** | `sac-johbarbe-AFRICOM-terraform-nac-ndo/data/ndo/schema_AFRICOM.nac.yaml` |

**Status:** ✅ implemented · 🟡 in flight · ⚪ planned · 🔴 blocked · ❓ undecided

**Phase model (matches `DESIGN.md`):**
- **Phase 1 — vzAny permit-all** (today): legacy and V2 coexist; vzAny+permit-all on both V2 VRFs; no ESGs in policy plane
- **Phase 2 — Lift-and-shift ESGs**: one big ESG per VRF; vzAny still permit-all; ESGs are observation-only
- **Phase 3 — Per-zone ESGs**: split big ESGs by tag selector; vzAny still permit-all
- **Phase 4 — ESG↔ESG contracts**: explicit allow-lists between ESGs; drop vzAny last

---

## Section A. Foundations (cross-phase)

### A1. Tenant model

**Today** ✅ — Single tenant `EUR` on both fabrics (Site1, Site2). Legacy AFRICOM schema and new AFRICOM-V2 schema both target this tenant. Coexistence is achieved via the `-V2` naming suffix.

**Recommendation:** Keep single tenant. Do not split into per-VRF or per-BU tenants. Multiple tenants give you only an RBAC boundary, which a single team does not need, and they multiply NDO templates.

**Source:** Belete-Strategy §1; Sharman §1 ("don't create 7 separate tenants"); WWT-Long §4 ("Single tenant model"); BRKDCN slide 70 ("Tenants for security boundaries… simpler is better when one team owns it"); DESIGN.

**Open questions for the team:**
- [ ] Are there any future BUs or external orgs that will need an RBAC boundary inside ACI in the next 24 months?
- [ ] Is there any compliance directive forcing per-mission tenant separation?

**Risk if not decided:** Low. Default position holds.

**Decision:** _________________________________________  **Re-visit:** _________

---

### A2. VRF count and boundaries

**Today** ✅ in V2, ✅ in legacy — Legacy AFRICOM has **11 VRFs**. V2 has **2 VRFs**: `VRF-EUR-V2` (internal + L2 DMZ where the gateway is external) and `VRF-DMZ-V2` (routed proxy DMZ requiring true routing isolation).

**Recommendation:** Keep the 2-VRF V2 layout. Use `VRF-EUR-V2` for everything where ESGs and contracts are sufficient for segmentation. Reserve `VRF-DMZ-V2` for proxy segments that need a hard L3 boundary with the rest of the estate. Do not re-introduce per-zone or per-application VRFs in V2.

**Source:** BRKDCN slides 22-29 ("VRFs add operational complexity without security value when ESGs+contracts handle segmentation"); NextGen ("combine VRFs where possible"); DESIGN. Note this is more aggressive than Sharman (kept 7 VRFs) and WWT-Long (kept 8-9). The Sharman position predates ESG multi-site shipping; it is now superseded.

**Open questions for the team:**
- [ ] Does anyone object to collapsing the 9 internal legacy VRFs (`EUR-AIM`, `EUR-AIS`, `EUR-AIV`, `EUR-AIZ`, `EUR-AIG`, `EUR-AIP`, `EUR-AOV-UC-DMZ`, `EUR-ARMY-ENT-SVR-DMZ`, `EUR-GSN-Test`, plus the catch-all) into the single `VRF-EUR-V2`?
- [ ] Are any of the legacy VRFs carrying overlapping IP ranges that would prevent the merge? (Spot-check: do any two VRFs hold the same prefix?)
- [ ] Does `VRF-DMZ-V2` need to stay logically isolated from `VRF-EUR-V2` at routing, or is contract-based isolation acceptable longer-term?

**Risk if not decided:** Phase 2 lift-and-shift cannot complete. ESG-All-Internal-V2 assumes everything internal lives in `VRF-EUR-V2`.

**Decision:** _________________________________________  **Re-visit:** _________

---

### A3. BD/EPG catalog (39 internal + 3 DMZ)

**Today** ✅ in V2, ✅ in legacy — Legacy AFRICOM has **215 BDs** (`BD-V0005` … `BD-V2205`, numeric/VLAN-derived) and **266 EPGs**. V2 schema has **39 BDs** and **39 EPGs** with descriptive names matched 1:1 to the IPv6 RCC catalog (`BD-AD-V2`, `BD-DB-SVR-V2`, `EPG-WEB-SVR-V2`, etc.) plus **3 DMZ EPGs** in `AppProf-DMZ-V2`.

**Recommendation:** Keep the 39+3 catalog. Do not aim for a smaller number — every consolidation beyond 39 risks merging subnets that have different security or operational profiles. The 1:1 EPG-per-BD pattern preserves the network-centric layer cleanly while ESGs become the security overlay.

**Source:** Schema-V2; DESIGN; OVERVIEW. Sharman recommended "199 BDs → ~30 over time"; you exceeded with 39 deliberately, mirroring the IPv6 RCC catalog. Belete-Strategy §3 endorses either service-based or app-based BDs — yours is a hybrid (functional like AD, infra like NTP/DNS, plus tier-based like WEB/APP/DB).

**Open questions for the team:**
- [ ] Confirm there are no IPv4 subnets in the legacy AFRICOM that do not map cleanly to one of the 39 V2 BDs.
- [ ] Are the 3 DMZ EPGs (`EPG-D64-PROXY-V2`, `EPG-FWEB-PROXY-V2`, `EPG-RWEB-PROXY-V2`) the complete DMZ catalog, or should more proxy/edge segments be promoted into V2?
- [ ] Any BDs that need anycast SVIs disabled (e.g., L2-only with external gateway)?

**Risk if not decided:** Endpoint cutover risks. Subnets without a target V2 BD have nowhere to land.

**Decision:** _________________________________________  **Re-visit:** _________

---

### A4. Naming convention (`-V2` suffix as generational marker)

**Today** ✅ — All V2 tenant-scoped objects (VRFs, BDs, EPGs, ANPs, contracts, ESGs) carry the `-V2` suffix. Legacy AFRICOM objects carry no suffix.

**Recommendation:** Treat `-V2` as **generational, not address-family-specific**. The suffix exists to allow legacy and redesign to live in the same tenant during cutover, and to let a future `-V3` slot in beside V2 if a third generation is ever needed. Document this in `OVERVIEW` and `DESIGN` so nobody assumes "V2 = IPv6".

**Source:** DESIGN ("naming convention is generational"); OVERVIEW; consistent with WWT-Long §4 ("clear naming conventions").

**Open questions for the team:**
- [ ] Confirm no objection to the `-V2` suffix being permanent (V2 objects will not be renamed back to non-suffixed once legacy AFRICOM is decommissioned, because that would be another endpoint-impacting cutover).
- [ ] Or alternatively: agree that after legacy AFRICOM is fully retired, a separate maintenance window will drop the `-V2` suffix in a controlled rename.

**Risk if not decided:** Cosmetic only today; matters for the eventual decommissioning plan.

**Decision:** _________________________________________  **Re-visit:** _________

---

### A5. Two-Terraform-roots architecture

**Today** ✅ — `aci-redesign/ndo/` (uses `netascode/nac-ndo/mso ~> 1.2.0`) manages tenant policy via NDO. `aci-redesign/apic-vmware/` and `apic-vmware-prod/` (use `netascode/nac-aci/aci 0.7.0`) manage APIC-direct items: access policies, AAEP, VPC, VLAN pools, VMware VMM domain, MCP, **and** the ESG layer (`AppProf-AppCentric-V2`). The split exists because `nac-ndo/mso` 1.2.x does not model `endpoint_security_groups`.

**Recommendation:** Keep the two-roots split until `nac-ndo` adds ESG support. When it does, plan a one-shot consolidation: move the ESG YAML from `apic-vmware/` into the NDO root, deploy via NDO, then remove the APIC-direct ESG block. Document this future move in `DESIGN` so the next operator knows.

**Source:** ESGs-V2 file header notes the gap; DESIGN; the absence of `endpoint_security_groups` in the `nac-ndo` schema is verifiable in the upstream module repo.

**Open questions for the team:**
- [ ] Who tracks the `nac-ndo` upstream module for ESG support? (WWT, Cisco TAC, you?)
- [ ] What is the trigger to consolidate — first `nac-ndo` minor release with ESGs, or wait for stable + N=1 patch?

**Risk if not decided:** None today. Becomes relevant only when the upstream module changes.

**Decision:** _________________________________________  **Re-visit:** _________

---

### A6. NDO orchestration model (single template, `deploy_templates=false`)

**Today** ✅ — V2 schema is a single template (`Tenant_EUR_V2`) in schema `AFRICOM-V2`. Legacy AFRICOM has 5 templates with explicit `deploy_order`. Both Terraform roots set `deploy_templates = false`; deploys go through the NDO UI in a documented order.

**Recommendation:** Keep `deploy_templates = false`. NDO 4.x has known behavior where Terraform-driven deployments of cross-template references can cycle. Manual NDO-UI deploys with a fixed order are slower per change but eliminate that class of failure. The single-template V2 schema reduces this risk further by having no cross-template dependencies inside V2.

**Source:** `aci-redesign/ndo/main.tf`; `sac-johbarbe-AFRICOM-terraform-nac-ndo/main.tf`; OVERVIEW; standard NAC-NDO operational guidance.

**Open questions for the team:**
- [ ] Is the manual deploy step documented as a runbook the on-call engineer can execute without your involvement?
- [ ] Should we set up NDO change notifications (email/Slack) so the team is alerted when a template is undeployed and pending?

**Risk if not decided:** Operational, not architectural. Risk that a partial deploy goes unnoticed and causes drift between Terraform state and NDO.

**Decision:** _________________________________________  **Re-visit:** _________

---

### A7. VMware VMM domain integration

**Today** ✅ — VMM domains `APCG-VDS1` (Site1) and `APCK-VDS1` (Site2) exist. Dynamic VLAN pool `vmm-vlan-pool` covers 3501-3967. AAEP `vmm-aaep` binds the VMM domain plus the physical domain. V2 EPGs declare `vmware_vmm_domains` per site with `deployment_immediacy: immediate` and `resolution_immediacy: immediate` (Schema-V2).

**Recommendation:** Keep the integration. Confirm `immediate/immediate` resolution is intentional (it forces VLAN programming on all leaves in the AAEP regardless of whether a VM is currently present — useful for vMotion/DRS, expensive on hardware resources). Consider `on-demand` resolution if VLAN consumption becomes a concern.

**Source:** WWT-Long §4 + WWT-Short §3 + Belete-Strategy §4 (all rate VMM as the highest-value Day-1 item); BRKDCN slides 109-111 (VMM + tag-driven ESGs); Schema-V2 EPG anchors block.

**Open questions for the team:**
- [ ] Is `immediate/immediate` the right choice fabric-wide, or should we move large-footprint EPGs to `on-demand` after Phase 2 baseline?
- [ ] Are there clusters that should NOT be in the VMM domain (e.g., bare-metal-only leaves, dedicated UCS clusters)?
- [ ] Is the 3501-3967 dynamic range large enough? (467 VLANs; 39 EPGs today; headroom is fine, but worth a sanity check against eventual app-tier EPG splits.)

**Risk if not decided:** Hardware resource consumption on leaves; no functional break.

**Decision:** _________________________________________  **Re-visit:** _________

---

### A8. Access policies — classic vs new interface configuration model

**Today** ✅ — Classic interface configuration model: VLAN pool → physical/VMM domain → AAEP → Interface Policy Group → Leaf interface profile → Leaf switch profile. NAC YAML uses the standard nested objects under `aci.access_policies`.

**Recommendation:** Keep the classic model for the brownfield V2 work. Only consider the new interface configuration model (`apic.new_interface_configuration: true`, BRKDCN slides 41-54) for greenfield fabrics. Switching mid-life would require re-platforming all interface objects with no functional benefit.

**Source:** BRKDCN slides 41-54; `aci-redesign/data/nac-aci-site1/access-policies.nac.yaml`; `…site2/…`.

**Open questions for the team:**
- [ ] Document the "stay classic" decision in `DESIGN` so a future maintainer doesn't try to "modernize" without understanding the trade-off.
- [ ] Any new fabrics planned in the next 24 months where the new model could be evaluated greenfield?

**Risk if not decided:** Low. Cosmetic.

**Decision:** _________________________________________  **Re-visit:** _________

---

### A9. MCP (Mis-Cabling Protocol)

**Today** ✅ — MCP Instance Policy is managed APIC-direct via `aci_rest_managed` resources in `apic-vmware/main.tf`, bypassing the `nac-aci` wrapper's MCP submodule (which had a `content["key"]` lifecycle issue). Each fabric gets a distinct CSPRNG-generated key. `pdu-per-vlan` and `port-disable` action are both enabled.

**Recommendation:** Keep this pattern. The CSPRNG key + per-fabric distinct values + port-disable action is a strong default. Verify the keys are stored as Terraform sensitive variables (not in plain `.tfvars`). Rotate keys on any suspected compromise or staff turnover.

**Source:** `aci-redesign/apic-vmware/main.tf`; `apic-vmware-prod/main.tf`; standard ACI operational guidance.

**Open questions for the team:**
- [ ] Are MCP keys stored in a vault or secrets manager, or only in masked GitLab CI variables?
- [ ] Is there a key-rotation policy? (Recommendation: annual + on staff change.)
- [ ] Has MCP been verified to actually disable a port in a controlled test? (If never tested, a real loop scenario will be the first test.)

**Risk if not decided:** A real cabling loop could black-hole a leaf; MCP is the safety net.

**Decision:** _________________________________________  **Re-visit:** _________

---

### A10. Application Profile separation (NetCentric / DMZ / AppCentric)

**Today** ✅ — Three Application Profiles inside `VRF-EUR-V2` and `VRF-DMZ-V2`:
- `AppProf-NetCentric-V2` — 36 internal EPGs (1:1 with internal BDs)
- `AppProf-DMZ-V2` — 3 DMZ EPGs (1:1 with DMZ BDs)
- `AppProf-AppCentric-V2` — ESG layer (`ESG-All-Internal-V2`, `ESG-All-DMZ-V2`)

**Recommendation:** Keep the three-AP split. It cleanly mirrors the BRKDCN model where BD/EPG provide the network-centric backing and ESGs provide the security overlay. Do not put EPGs and ESGs in the same AP; the separation makes Phase 2/3/4 work much easier to reason about.

**Source:** Schema-V2; ESGs-V2; BRKDCN slide 27 ("BD provides VNI, EPG provides VLAN backing, ESG defines security group").

**Open questions for the team:**
- [ ] Confirm naming standard for any future ESG additions: do they go in `AppProf-AppCentric-V2` (today's pattern) or in per-application APs (`AppProf-<App>-V2`) once Phase 3 splits start?
- [ ] If per-app APs are introduced, decide upfront whether the `AppProf-AppCentric-V2` umbrella stays for cross-app ESGs (e.g., `ESG-All-Internal-V2` for emergency rollback) or is retired.

**Risk if not decided:** Operational confusion if Phase 3 splits land without an AP convention.

**Decision:** _________________________________________  **Re-visit:** _________

---

## Section B. Phase 1 — vzAny permit-all (today)

### B1. vzAny scope and the `Any_VRF-*-V2` contracts

**Today** ✅ — Both V2 VRFs set `vzany: true`. Both VRFs provide and consume their own `Any_VRF-*-V2` contract (Schema-V2, around lines 113-122 of the schema YAML). The contracts reference the cross-schema filter `AFRICOM/VRF_Template/Any` for a single source of truth.

**Recommendation:** Keep this exactly through Phase 2 and Phase 3. The vzAny+permit-all scaffolding is the safety net that lets ESGs go in without breaking endpoint-to-endpoint reachability. Removing vzAny is **only** a Phase 4 step, after explicit ESG-to-ESG contracts cover all flows that need to exist.

**Source:** Sharman §3 ("Don't remove vzAny until fully confident in ESG setup"); BRKDCN slide 35 ("Use vzAny for intra-application communication" until you can replace it); WWT-Long Phase 1.

**Open questions for the team:**
- [ ] Confirm there is no audit / compliance requirement that prohibits VRF-wide permit-all today (some sites have explicit policy against this).
- [ ] If yes, is the auditor satisfied by a documented migration plan with target date for vzAny removal?

**Risk if not decided:** Compliance finding could force an emergency re-architecture.

**Decision:** _________________________________________  **Re-visit:** _________

---

### B2. Filter `Any` and the `log` directive

**Today** ✅ — The `Any` filter (defined in `AFRICOM/VRF_Template`) has a single entry with `directives: [log, none]`. Every flow that hits vzAny+permit-all generates a contract-hit log line on the leaf.

**Recommendation:** Consider toggling the `log` directive **off** on the bulk vzAny `Any` filter once ESG visibility (per-ESG endpoint listing in APIC, Endpoint Tracker, NDI flow analysis) is verified to give equivalent forensic value. Per-flow logging on a vzAny+permit-all VRF can pressure leaf CPU and policy-CAM.

**Source:** Operational guidance; BRKDCN slides 99-101 (ESG visibility tooling).

**Open questions for the team:**
- [ ] Has anyone observed leaf CPU pressure or log-buffer pressure attributable to the `log` directive?
- [ ] Is there a forensic / compliance requirement that depends on contract-hit logging specifically (vs flow logging at the firewall or NDI)?
- [ ] If we turn off `log`, do we need to re-enable it temporarily during Phase 4 contract validation?

**Risk if not decided:** Operational only. If problems appear later, this is the first knob to turn.

**Decision:** _________________________________________  **Re-visit:** _________

---

### B3. Static port bindings (Python script vs Terraform)

**Today** ✅ — Static port bindings (EPG-to-leaf-port mappings) are pushed by Python scripts under `aci-redesign/scripts/` (`deploy_bindings.py`, `dump_bindings.py`, `check_fi_bindings_parity.py`, `generate_fi_bindings.py`). They are **not** modeled in the V2 NDO schema.

**Recommendation:** Keep bindings out of the NDO schema. NDO does not own static port bindings cleanly across sites (each site's leaves are local), and `nac-ndo` would multiply the per-binding objects significantly. The current Python pattern lets you generate bindings from upstream sources of truth (FI epg manifest, n5k extracts) and push them at deploy time. Treat `scripts/` as a first-class part of the deploy pipeline, not a sidecar.

**Source:** `aci-redesign/scripts/`; `aci-redesign/README.md`.

**Open questions for the team:**
- [ ] Are the Python scripts in CI, or run manually?
- [ ] Is there a dry-run / diff mode that shows what bindings would change before they apply?
- [ ] Do the scripts have a parity check against APIC after the push? (`check_fi_bindings_parity.py` suggests yes — confirm it runs as part of the standard deploy.)

**Risk if not decided:** Bindings drift without anyone noticing; first symptom is a host that lost its EPG mapping after a re-cable.

**Decision:** _________________________________________  **Re-visit:** _________

---

## Section C. Phase 2 — Lift-and-shift ESGs (in flight)

### C1. Scope of `ESG-All-Internal-V2` and `ESG-All-DMZ-V2`

**Today** ✅ — Two ESGs declared in `tenant-eur-esgs.nac.yaml`:
- `ESG-All-Internal-V2` in `VRF-EUR-V2`, with `epg_selectors` listing all 36 internal EPGs
- `ESG-All-DMZ-V2` in `VRF-DMZ-V2`, with `epg_selectors` listing the 3 DMZ EPGs

Both have `intra_esg_isolation: false` and `preferred_group: false`. vzAny permit-all is still the active reachability policy.

**Recommendation:** Keep this scope through Phase 2. Resist the temptation to start splitting before Phase 2 has a verified baseline. The point of Phase 2 is to confirm every endpoint correctly classifies into the right ESG with no behavior change.

**Source:** ESGs-V2; DESIGN; Sharman §4 ("Phase 1: vzAny → permit all"); BRKDCN slide 75 (single ESG to single VRF mapping).

**Open questions for the team:**
- [ ] Define the exit criteria for Phase 2 → Phase 3. Suggested: (a) every endpoint in `VRF-EUR-V2` shows up under `ESG-All-Internal-V2` in APIC's per-ESG endpoint view; (b) NDI flow analysis confirms no flows are being mis-categorized; (c) at least one full business cycle (week or month) of observation.
- [ ] How long does Phase 2 run before Phase 3 starts? (Suggestion: minimum 30 days, longer if app discovery is incomplete.)

**Risk if not decided:** Phase 3 begins before Phase 2 baseline is solid; classification mistakes get inherited into per-zone ESGs and are harder to find later.

**Decision:** _________________________________________  **Re-visit:** _________

---

### C2. Selector method for Phase 2

**Today** ✅ — EPG selectors. Each ESG enumerates the EPGs it includes by name (AppProf + EPG).

**Recommendation:** Keep EPG selectors for Phase 2. They are deterministic and easy to audit. Do not introduce IP-, MAC-, or tag-selectors at this phase — save those for Phase 3 when you actually need to split by attribute.

**Source:** ESGs-V2; BRKDCN slide 75; Sharman §4.

**Open questions for the team:**
- [ ] Confirm the EPG selector list in `ESG-All-Internal-V2` is exhaustive — anyone can verify by counting selectors and comparing to the EPG count in `AppProf-NetCentric-V2`.
- [ ] When a new internal EPG is added to V2 in the future, what is the procedure for adding it to `ESG-All-Internal-V2`? (Suggestion: same PR adds both.)

**Risk if not decided:** Endpoints in a new EPG would not be governed by any ESG; vzAny still gives them reachability but they would be invisible in per-ESG views.

**Decision:** _________________________________________  **Re-visit:** _________

---

### C3. Phase 2 verification & baseline

**Today** ⚪ — No documented verification procedure exists yet. The Phase 2 deploy steps in `aci-redesign/README.md` mention "verify" but do not list specific checks.

**Recommendation:** Document a fixed Phase 2 verification checklist before any production deploy. Suggested checks:
1. APIC GUI → tenant EUR → AppProf-AppCentric-V2 → ESG-All-Internal-V2 → Endpoints tab. Endpoint count should match the sum of endpoints across the 36 contributing EPGs (within normal vMotion drift).
2. Same check for `ESG-All-DMZ-V2`.
3. NDI flow analysis: no flows should now be denied that were previously allowed. (vzAny+permit-all is still in effect, so this should be trivially true.)
4. Spot-check 3-5 endpoints across different EPGs: confirm they appear in the right ESG and only in that ESG.
5. Capture a baseline snapshot (CSV export of per-ESG endpoint list) for Phase 3 comparison.

**Source:** WWT-Long Phase 2 ("Testing and Validation" + "Performance benchmarking"); BRKDCN slides 99-101.

**Open questions for the team:**
- [ ] Who owns the verification checklist? (Suggestion: the engineer who runs the deploy.)
- [ ] Where does the baseline snapshot get stored? (Git? Wiki? Shared drive?)
- [ ] Do we need a rollback procedure documented for Phase 2? (It's safe — ESGs are observation-only with vzAny permit-all — but a documented rollback is good practice.)

**Risk if not decided:** Baseline drift is hard to detect later. Phase 3 splits depend on knowing the Phase 2 starting state precisely.

**Decision:** _________________________________________  **Re-visit:** _________

---

### C4. ESG governance — who can add an EPG to an ESG?

**Today** ❓ — No written governance. ESG membership lives in `tenant-eur-esgs.nac.yaml`, which is in Git, so changes go through PR review. But there is no documented owner.

**Recommendation:** Name a single approver for ESG-membership PRs. ESGs are the security policy layer; once Phase 4 contracts land, an unintended membership change can change what an endpoint is allowed to talk to. Treat ESG membership as a security-relevant change, not a network change.

**Source:** Implicit in Sharman §11 ("Don't rush BD consolidation"); inherent to ESG-as-security model.

**Open questions for the team:**
- [ ] Who is the named approver? (Primary + backup.)
- [ ] Is there a separate review path for emergency / break-glass ESG changes (e.g., security incident requiring rapid quarantine)?
- [ ] Should the approver list be in CODEOWNERS or in `DESIGN`?

**Risk if not decided:** Phase 4 starts and a misconfigured ESG silently changes who can talk to whom.

**Decision:** _________________________________________  **Re-visit:** _________

---

## Section D. Phase 3 — Per-zone ESGs via tag selectors (planned)

### D1. Splitting strategy — by zone, by tier, or by app?

**Today** ⚪ — `DESIGN.md` and `tenant-eur-esgs.nac.yaml` header reference Phase 3 splits ("zone-specific ESGs using `tag_selectors`") but no concrete split list exists yet.

**Recommendation:** Pick ONE primary axis for the first Phase 3 wave:
- **By zone** (e.g., `ESG-AIM-V2`, `ESG-AIS-V2`, `ESG-AIV-V2` matching the legacy VRF zone identities). Quick win because the zones are already known. Maps directly to historical security boundaries.
- **By tier** (e.g., `ESG-WEB-V2`, `ESG-APP-V2`, `ESG-DB-V2`). Aligns with the BD catalog and makes contract authoring obvious (web→app→db). Requires reliable tier classification per VM.
- **By app** (e.g., `ESG-HR-V2`, `ESG-AD-V2`, `ESG-Backup-V2`). Highest value, hardest to do without application discovery.

**Suggested first wave: by zone**, because (a) the zone identity already exists in legacy VRF names, (b) it gives an immediate replacement story for the legacy VRFs you collapsed, (c) tier and app splits can be layered on top in later waves using additional tag selectors per ESG.

**Source:** BRKDCN slides 80, 109-111 (tag-selector ESGs); Sharman §3 ("application-specific ESGs"); WWT-Long Phase 3.

**Open questions for the team:**
- [ ] Which axis goes first? (Recommendation: zone.)
- [ ] How many ESGs in the first wave? (Suggestion: cap at 10-12, matching the legacy VRF count.)
- [ ] Do we need a "catch-all" ESG for endpoints that don't match any zone tag, or do we treat lack-of-tag as a deploy blocker for that VM?

**Risk if not decided:** Phase 3 stalls. Or worse, different teams pick different axes and you end up with overlapping ESG schemes.

**Decision:** _________________________________________  **Re-visit:** _________

---

### D2. vCenter tag scheme and ownership

**Today** ❓ — `tenant-eur-esgs.nac.yaml` header references `aci-zone`, `aci-tier`, `aci-app` placeholders but the actual vCenter tag scheme does not exist yet. No documented owner.

**Recommendation:** Define the tag scheme **before** any Phase 3 work begins. Suggested scheme:

| Tag category | Example values | Owner | Mandatory? |
|---|---|---|---|
| `aci-zone` | `aim`, `ais`, `aiv`, `aiz`, `aig`, `aip`, `aov`, `army`, `gsn`, `dmz` | Network team | Yes (Phase 3) |
| `aci-tier` | `web`, `app`, `db`, `infra`, `mgmt`, `proxy` | App owner / Network team | Optional (Phase 3 wave 2) |
| `aci-app` | `hr`, `finance`, `ad`, `backup`, … | App owner | Optional (Phase 4) |

Tags are set in vCenter and read by ACI's VMware VMM integration. ESG tag selectors then match endpoint tags to ESG membership.

**Source:** BRKDCN slides 109-111; ESGs-V2 file header.

**Open questions for the team:**
- [ ] Who owns the vCenter tag scheme — Network team, vCenter/VMware team, or jointly?
- [ ] Who maintains the documented value list (the rows of the table above) and approves new values?
- [ ] What is the procedure for tagging an existing VM that has no tag today? (Manual UI? API script? PowerCLI?)
- [ ] What is the procedure for tagging a new VM at provision time? (vRA? Manual? Provisioning runbook?)
- [ ] What happens to a VM with a tag value that doesn't match any ESG selector — does it fall to a default ESG, or stay unassigned?
- [ ] Do bare-metal hosts need an equivalent classification path (since they don't have vCenter tags)? If yes, by IP selector or MAC selector?

**Risk if not decided:** Phase 3 cannot start. This is the single biggest non-tooling blocker for the redesign.

**Decision:** _________________________________________  **Re-visit:** _________

---

### D3. Application Dependency Mapping (ADM) procedure

**Today** ❓ — Every WWT/Belete/Sharman doc names ADM as the #1 risk. No procedure exists in the repos. NDI is the only available tool (Tetration/CSW are not budgeted).

**Recommendation:** Document a Phase 2.5 procedure (between Phase 2 baseline and Phase 3 split work):

1. **Enable NDI flow analysis** for VRF-EUR-V2 and VRF-DMZ-V2.
2. **Capture baseline** during a representative business cycle (suggestion: 4 weeks covering a month-end and a quarter-end).
3. **Pull flows by source ESG → destination ESG**. Today this is `ESG-All-Internal-V2 → ESG-All-Internal-V2` and `ESG-All-Internal-V2 → ESG-All-DMZ-V2` and external. That tells you the bulk volume but not the application breakdown.
4. **Pull flows by source IP → destination IP → port**. Group by /24 or /27 prefix to find clusters. Cross-reference with ServiceNow CMDB if available.
5. **Interview application owners** for the top 5 by flow volume. Confirm what each flow represents.
6. **Output**: a CSV per app with columns: app name, source ESG (target Phase 3 ESG), destination ESG (target), protocol, port, expected volume, owner.

**Source:** WWT-Long §8 ("Application Dependency Mapping"); WWT-Short §3; Belete-Strategy "Application Dependency Mapping"; Sharman §10.

**Open questions for the team:**
- [ ] Who runs the NDI capture and analysis?
- [ ] What is the CMDB source of record (ServiceNow, spreadsheet, none)?
- [ ] Who interviews app owners — Network team, or do we need an app-side liaison?
- [ ] Does the output CSV become a tracked artifact (Git? Confluence?) so Phase 3/4 contract authoring can reference a known version?
- [ ] What is the policy when an undocumented flow shows up — block, log, or auto-add to the relevant ESG?

**Risk if not decided:** Phase 3/4 contract authoring is guesswork. Unknown flows break apps when vzAny is removed.

**Decision:** _________________________________________  **Re-visit:** _________

---

### D4. Tag-selector vs IP-selector vs MAC-selector — when to use each

**Today** ⚪ — Selector choice is implicit in the YAML structure but no documented convention.

**Recommendation:** Pick the selector type by use case, not personal preference:

| Selector | Use when | Avoid when |
|---|---|---|
| **EPG selector** | Phase 2 lift-and-shift, or Phase 3 when you want every endpoint of an EPG in the same ESG with no exceptions | Endpoints of a single EPG belong to multiple ESGs |
| **Tag selector** | Phase 3 splits driven by vCenter tags (apps, tiers, zones); the natural fit for VM workloads | Bare-metal endpoints with no tag source |
| **IP selector** | Bare-metal endpoints, hardware appliances, or external IPs that need ESG classification | Subnets that span multiple intended ESGs |
| **MAC selector** | Switch-traffic endpoints, hardware appliances with stable MACs (BRKDCN: "use MAC tags for higher priority for switch traffic") | VM workloads (MAC changes on vMotion in some configs) |

Document this matrix in `DESIGN`.

**Source:** BRKDCN slides 75, 80, 88; Sharman §4 ("Steve's Easier Method"); ESGs-V2.

**Open questions for the team:**
- [ ] How many bare-metal hosts are in scope, and how stable are their MACs?
- [ ] Do we expect IP-selector ESGs (e.g., for an external partner IP that needs to talk to a specific app)?
- [ ] Do we want to forbid one or more selector types to keep the model simple?

**Risk if not decided:** Inconsistent selector choices across Phase 3 ESGs make the policy hard to audit.

**Decision:** _________________________________________  **Re-visit:** _________

---

### D5. Naming for per-zone ESGs

**Today** ⚪ — No convention yet.

**Recommendation:** Adopt a single name pattern and stick with it. Suggested:

| Pattern | Example | Notes |
|---|---|---|
| `ESG-<zone>-V2` | `ESG-AIM-V2`, `ESG-AIS-V2` | Zone wave (recommended first wave) |
| `ESG-<zone>-<tier>-V2` | `ESG-AIM-WEB-V2`, `ESG-AIM-DB-V2` | Tier wave (second pass) |
| `ESG-<app>-V2` | `ESG-HR-V2`, `ESG-AD-V2` | App wave (third pass; rare, only for apps with their own segmentation needs) |
| `ESG-Outside-V2` | `ESG-Outside-V2` | External classification (per-VRF, post-6.1(4)) — see Section F |

Keep `ESG-All-Internal-V2` and `ESG-All-DMZ-V2` as the umbrella (Phase 2) ESGs even after Phase 3, so an emergency "let everything talk" rollback is one membership change.

**Source:** BRKDCN slide 117 (clear naming); the convention itself.

**Open questions for the team:**
- [ ] Approve the pattern, or propose alternatives.
- [ ] Decide whether `ESG-All-Internal-V2` stays as a permanent umbrella or is retired after Phase 3 stabilizes.
- [ ] Confirm the `-V2` suffix carries through to Phase 3 ESGs (consistent with A4).

**Risk if not decided:** Naming collisions or inconsistencies; cosmetic but annoying.

**Decision:** _________________________________________  **Re-visit:** _________

---

### D6. Selector ordering & MAC-tag priority for switch traffic

**Today** ⚪ — Not addressed yet.

**Recommendation:** Sharman §4 calls out "use MAC tags for higher priority (switch traffic)" — this matters when an endpoint could match multiple selectors and you want a deterministic outcome. ACI evaluates ESG selectors with a defined priority order; document the chosen ordering once you have multi-selector ESGs.

**Source:** Sharman §4; ACI ESG documentation.

**Open questions for the team:**
- [ ] Are there any endpoints today (or planned) that would match multiple ESG selectors?
- [ ] Has anyone validated selector evaluation order in your specific ACI version?

**Risk if not decided:** Low until multi-selector ESGs land. Then potentially confusing if not documented.

**Decision:** _________________________________________  **Re-visit:** _________

---

## Section E. Phase 4 — ESG↔ESG contracts (future)

### E1. Contract / subject / filter / entry naming convention

**Today** ⚪ — Only one filter exists today: `Any` (permit any/any with `log` directive). When Phase 4 starts, you will write 50-200 contracts. Setting the convention now is essentially free; refactoring later is not.

**Recommendation:** Adopt the BRKDCN slide 117 convention:

| Object | Pattern | Example |
|---|---|---|
| Contract | `permit-to-<provider-ESG>` | `permit-to-ESG-DB-V2` |
| Subject | `<protocol>` (one subject per protocol family) | `tcp`, `udp`, `icmp` |
| Filter | `<protocol>-src-any-dst-<port>` | `tcp-src-any-dst-3306` |
| Entry | same as filter (1:1) | `tcp-src-any-dst-3306` |

Contract scope: `vrf` for intra-VRF flows. Reverse filter ports: enabled (default).

Document one named exception: an `intra-vrf` contract on vzAny that stays permit-all for any flow you decide to leave open. BRKDCN slide 35 calls this out as the natural last vzAny contract before final removal.

**Source:** BRKDCN slides 35, 117, 118; Belete-Strategy "Contract Strategy".

**Open questions for the team:**
- [ ] Approve the naming convention, or propose alternatives.
- [ ] Decide whether contracts are bidirectional (`type: bothWay`) or one-way (separate provider/consumer). Recommendation: `bothWay` for symmetry with the existing `Any_VRF-*-V2` pattern.
- [ ] Decide on contract scope default (`vrf` vs `application_profile` vs `tenant`). Recommendation: `vrf`.
- [ ] Where do filters live — under `VRF_Template` (legacy) or under `Tenant_EUR_V2` (V2)? Recommendation: V2 owns its own filters in the V2 schema, except for the legacy `Any` which stays where it is.

**Risk if not decided:** Inconsistent contract names make audit and troubleshooting painful at scale.

**Decision:** _________________________________________  **Re-visit:** _________

---

### E2. Filter granularity — per-protocol, per-port, stateful?

**Today** ⚪ — Single `Any` filter today (any protocol, any port, no stateful flag).

**Recommendation:**
- One filter entry per (protocol, destination port) tuple. Source port stays `unspecified`.
- Use `stateful: true` for TCP filters where reverse flow should be auto-permitted by the leaf. Off for UDP and ICMP.
- Avoid wildcard ranges except when intentional (e.g., `dst_from_port: 49152, dst_to_port: 65535` for ephemeral RPC).
- Group related entries into named filters per app cluster (e.g., `oracle-db-ports` containing 1521, 1525, 2483) to keep the contract list readable.

**Source:** BRKDCN slides 117-119; standard contract design guidance.

**Open questions for the team:**
- [ ] Are there apps using non-standard ports that need filter naming exceptions?
- [ ] Are there apps using ephemeral port ranges that should be allowed wholesale (some legacy RPC)?
- [ ] Stateful default = on for TCP, off for UDP/ICMP — agree?

**Risk if not decided:** Filter sprawl. 200 filters with inconsistent naming becomes unmaintainable.

**Decision:** _________________________________________  **Re-visit:** _________

---

### E3. Sequencing — which application gets restricted first?

**Today** ⚪ — No sequencing.

**Recommendation:** Pick a low-risk pilot first. Suggested criteria:
1. Application is well-understood (you know all its flows from D3 ADM work).
2. Application has a clear maintenance window where rollback is acceptable.
3. Application is NOT mission-critical (don't pilot on AD or backup).
4. Application has a small endpoint count (single-digit hosts).
5. Application owner is responsive and on-call during the change.

Suggested pilot candidates (you'll need to confirm based on what fits): an internal monitoring tool, a small developer service, or a non-prod Tier-1 app. Run the pilot for 2-4 weeks before adding the second app.

**Source:** WWT-Long Phase 3 ("Critical Applications First"); Sharman §10 ("Start with low-risk apps").

**Open questions for the team:**
- [ ] Who selects the pilot app — Network team or App team?
- [ ] Do we need a documented rollback runbook per app before that app's contract goes live?
- [ ] Is there a maximum number of apps that can be in the "restricted via Phase 4 contracts" state at once before vzAny is removed? (Suggestion: don't remove vzAny until at least the top-N apps by flow volume are explicitly contracted.)

**Risk if not decided:** Phase 4 stalls because nobody picks the first app. Or starts with the wrong app and breaks production.

**Decision:** _________________________________________  **Re-visit:** _________

---

### E4. vzAny removal procedure

**Today** ⚪ — `DESIGN.md` Phase 4 says "Remove `vzany: true` on each VRF last".

**Recommendation:** Document the removal as its own change with explicit prerequisites:

1. **Prerequisite checklist** (all must be ✓ before vzAny is removed):
   - All "must talk" flows from D3 ADM are covered by ESG↔ESG contracts.
   - Flow logs show zero hits on vzAny+permit-all over the past N days (suggestion: 30 days) for any flow not also covered by an explicit contract.
   - Rollback plan exists: re-add `vzany: true` and the `Any_VRF-*-V2` contract, then re-deploy.
   - Maintenance window scheduled.
   - Stakeholders notified.

2. **The change itself**: edit `schema-africom-v2.nac.yaml` to set `vzany: false` (or remove the block) on `VRF-EUR-V2`. Deploy through NDO. **Do NOT do both VRFs in the same window.** Do `VRF-DMZ-V2` first (smaller blast radius), then `VRF-EUR-V2` after a stabilization period.

3. **Post-change observation**: monitor NDI for unexpected denies for at least 7 days.

**Source:** BRKDCN slide 35; Sharman §3 ("Don't remove vzAny until fully confident"); standard change practice.

**Open questions for the team:**
- [ ] Approve the "DMZ first, EUR later" sequence?
- [ ] Approve the "30-day zero-hit" prerequisite, or pick a different threshold?
- [ ] Define what counts as a "must talk" flow (any flow seen in NDI vs flows with documented business need)?

**Risk if not decided:** Phase 4 either never finishes or finishes badly (premature vzAny removal causes outage).

**Decision:** _________________________________________  **Re-visit:** _________

---

## Section F. L3Out blueprint (cross-phase, gating Phase 3+)

This section is grouped because L3Outs are an undecided cross-phase topic. Most items are interlinked.

### F1. L3Out ownership in V2

**Today** ⚪ — V2 schema declares **zero L3Outs**. North-south routing for `VRF-EUR-V2` and `VRF-DMZ-V2` is currently provided by the L3Outs that already exist in the legacy AFRICOM schema (13 L3Outs total: per-VRF, per-site `L3Out-G_*` and `L3Out-K_*`).

**Recommendation:** Decide **now** whether V2 will own its own L3Outs or continue inheriting from legacy AFRICOM. Two options:

- **Option A — V2 owns L3Outs.** Add `l3outs:` and `external_endpoint_groups:` blocks to `schema-africom-v2.nac.yaml`. New L3Outs are created in `EUR` tenant, scoped to `VRF-EUR-V2` and `VRF-DMZ-V2`. Eventually the legacy AFRICOM L3Outs are decommissioned.
- **Option B — V2 inherits indefinitely.** Keep using the legacy L3Outs. AFRICOM schema stays partially live forever, just for L3Outs.

**Recommended: Option A** with phased migration. Continuing to depend on AFRICOM for L3Outs prevents you from ever fully retiring the legacy schema, and creates a confusing two-headed ownership model.

**Source:** DESIGN ("L3Outs and External EPGs are NOT declared in this schema… provided by the L3Outs that already exist in the legacy IPv6 schema"); BRKDCN slides 70-71; Belete-Strategy §6 ("Consolidate L3Outs where possible").

**Open questions for the team:**
- [ ] Pick A or B.
- [ ] If A: what is the cutover sequence? (Suggestion: build new V2 L3Outs, peer them in parallel with legacy, drain traffic, decommission legacy.)
- [ ] If A: are there any FW/upstream router config dependencies that would block creating new V2 L3Outs?
- [ ] If B: what is the long-term plan for fully retiring AFRICOM? (B is incompatible with full retirement.)

**Risk if not decided:** OVERVIEW currently says "later"; "later" needs a date.

**Decision:** _________________________________________  **Re-visit:** _________

---

### F2. L3Out pattern — dedicated per-VRF or shared?

**Today** ✅ in legacy — Legacy AFRICOM follows the **dedicated per-VRF** pattern (each of the 9-10 VRFs has its own per-site L3Out, no sharing).

**Recommendation:** For V2, adopt **Option 1: dedicated L3Out per VRF** in tenant `EUR`. Two reasons:
1. You only have 2 VRFs in V2, so the "shared L3Out in a `shared-services` tenant" pattern (BRKDCN slide 71) gives you nothing — there is no second tenant to share with.
2. Dedicated L3Outs avoid all the route-leaking complexity that BRKDCN slides 64-68 warn about.

Concretely, four L3Outs in V2:
- `L3Out-EUR-V2-G_to_core` (VRF-EUR-V2, Site1)
- `L3Out-EUR-V2-K_to_core` (VRF-EUR-V2, Site2)
- `L3Out-DMZ-V2-G_to_core` (VRF-DMZ-V2, Site1)
- `L3Out-DMZ-V2-K_to_core` (VRF-DMZ-V2, Site2)

**Source:** BRKDCN slides 70-71; consistent with current AFRICOM topology.

**Open questions for the team:**
- [ ] Approve the dedicated-per-VRF pattern.
- [ ] Approve the four-L3Out naming proposal, or modify.
- [ ] Confirm both `VRF-EUR-V2` and `VRF-DMZ-V2` peer with the same upstream device(s), or document where they differ.

**Risk if not decided:** F1 cannot be implemented without F2 settled.

**Decision:** _________________________________________  **Re-visit:** _________

---

### F3. External classification — extEPG vs ESG (post-6.1(4))

**Today** ⚪ — Legacy AFRICOM uses the classic pattern: external IPs are classified into `External Endpoint Groups` (extEPGs) like `ExtEPG-AIM`, `ExtEPG-AIS`, with subnets `0.0.0.0/1` and `128.0.0.0/1` covering "everything external". Contracts attach to the extEPG.

**Recommendation:** For V2, use the post-6.1(4) decoupled model where external IPs are classified directly into ESGs via **External EPG Selectors**. This gives a single classification model (ESG) for both internal and external endpoints. Your contracts become uniformly ESG↔ESG.

Concretely, add a per-VRF `ESG-Outside-V2` ESG that uses an External EPG Selector pointing at the V2 extEPG. Contracts then attach to `ESG-Outside-V2`, not the extEPG.

**Source:** BRKDCN slides 86-89 (post-6.1(4) "external IPs can be classified into an ESG"); slide 89 ("common classification method from overlay, campus, CNI, etc.").

**Open questions for the team:**
- [ ] Approve the ESG-based external classification pattern for V2.
- [ ] Confirm the ACI version in production supports External EPG Selectors (requires 6.1(4) or later).
- [ ] Decide if the legacy extEPGs in AFRICOM also get retrofit with this pattern, or stay classic until the schema is decommissioned.

**Risk if not decided:** If V2 L3Outs are built with classic extEPG-only classification, you'll later need to refactor every external-facing contract.

**Decision:** _________________________________________  **Re-visit:** _________

---

### F4. Route control gotcha (relevant if any inter-VRF leak ever needed)

**Today** ✅ — No inter-VRF route leaking. All inter-VRF traffic goes through the firewall. This is the documented design.

**Recommendation:** Keep no leaking as the default. **Document the BRKDCN slide 66-68 gotcha** in `DESIGN` so anyone who ever does need to add leak rules knows the trap:

- The classic pattern of declaring `0.0.0.0/1` + `128.0.0.0/1` on an extEPG with **only** "External Subnets for the extEPG" flag will **NOT** leak routes — those two halves never match received routes (BRKDCN slide 66, "THESE ROUTES WILL NEVER MATCH").
- To leak, you must either add the **`Aggregate Shared Routes`** flag on each half (BRKDCN slide 67) or add a literal `0.0.0.0/0` line with the **`Shared Route Control Subnet`** flag (BRKDCN slide 68).

This is a documentation-only item: write it down so it's not relearned the hard way.

**Source:** BRKDCN slides 64-68.

**Open questions for the team:**
- [ ] Confirm no inter-VRF leak is needed in V2 today.
- [ ] Add the gotcha note to `DESIGN` as a "future operators read this" callout.

**Risk if not decided:** Low. Becomes high if someone ever needs to enable a leak and skips this footgun.

**Decision:** _________________________________________  **Re-visit:** _________

---

### F5. BGP hardening checklist for V2 L3Outs

**Today** ⚪ — Legacy AFRICOM L3Out BGP hardening posture is unverified in YAML; may be set on APIC manually.

**Recommendation:** When V2 L3Outs are built (F1 Option A), apply the BRKDCN BGP hardening checklist to each peer:

| Setting | Recommended value | BRKDCN ref |
|---|---|---|
| BGP password | Set (per peer or per L3Out) | slide 154 |
| Max AS limit | `1` (only direct upstream) | slide 154 |
| Peer prefix policy `max_prefixes` | Cap (e.g., 1000), action `reject` | slide 154 |
| BFD | On if upstream supports | slide 154 |
| Route control: import | Allowlist subnets only | slide 154 |
| Route control: next hop propagation | On for transit | slide 154 |
| Route control: multipath | On if multiple peers | slide 154 |

These map to NAC YAML primitives: `bgp_timer_policies`, `bgp_address_family_context_policies`, `bgp_peer_prefix_policies`, `bgp_best_path_policies`, `route_control_route_maps`, `set_rules` (BRKDCN slides 155-160).

**Source:** BRKDCN slides 154-160.

**Open questions for the team:**
- [ ] Audit the existing legacy AFRICOM L3Outs against this checklist (snapshot APIC, compare to YAML, codify any gaps in YAML so they survive a rebuild).
- [ ] Apply the checklist to new V2 L3Outs from day 1.
- [ ] Are there upstream device constraints (e.g., FW doesn't support BFD) that force some items off?

**Risk if not decided:** Defense-in-depth gap. Not a bug today but a hardening miss.

**Decision:** _________________________________________  **Re-visit:** _________

---

## Section G. Future / planning

### G1. nac-ndo ESG support — when to consolidate the two-roots split

**Today** 🔴 — Blocked on upstream `nac-ndo/mso` adding `endpoint_security_groups` modeling.

**Recommendation:** Track the upstream module. When ESGs land (likely as a new minor release), wait one patch cycle for stability, then plan a one-shot consolidation:
1. Move the ESG block from `apic-vmware/` (using `nac-aci`) into `aci-redesign/ndo/` (using `nac-ndo`).
2. Remove the ESG block from APIC-direct YAML.
3. Verify ESG ownership transfers cleanly (NDO becomes the source of truth).
4. Re-test Phase 2 verification checklist.

**Source:** A5; upstream module status.

**Open questions for the team:**
- [ ] Who watches the `netascode/nac-ndo` repo for ESG support?
- [ ] What is the trigger to consolidate — first release with ESGs, or stable + 1 patch?
- [ ] Is it OK to do the consolidation as a single change, or do we want a rollback period?

**Risk if not decided:** None today. Eventual technical debt if we never consolidate.

**Decision:** _________________________________________  **Re-visit:** _________

---

### G2. IPv6 dual-stack absorption into V2 BDs

**Today** ⚪ — V2 BDs are designed to absorb dual-stack subnets (DESIGN, OVERVIEW). The original IPv6 mandate generated the BD catalog; V2 is the IPv4 implementation of that catalog. IPv6 has not been populated yet.

**Recommendation:** When IPv6 deployment resumes:
1. Add IPv6 subnet block to each V2 BD that needs it (Schema-V2: extend `subnets` list).
2. Confirm BD setting `unicast_routing: true` and IPv6-specific knobs (ND policy, RA policy).
3. Multi-site underlay note: until ACI supports IPv6 underlay across ISN, you stay IPv4 underlay + dual-stack overlay (WWT-Long §6).
4. Coordinate with the L3Out blueprint (F1, F2): V2 L3Outs should be born dual-stack-ready (BGP IPv4 unicast + IPv6 unicast address families).

**Source:** WWT-Long §6 (IPv6 priority); WWT-Short §5; OVERVIEW; DESIGN.

**Open questions for the team:**
- [ ] Is IPv6 still on the roadmap, and on what timeline?
- [ ] Which BDs get IPv6 first? (Suggestion: management/infra BDs first, then per-zone.)
- [ ] Who provides IPv6 prefix assignments — same source as IPv4, or a separate IPAM workflow?

**Risk if not decided:** No risk today. Becomes relevant when the IPv6 mandate re-surfaces.

**Decision:** _________________________________________  **Re-visit:** _________

---

### G3. Phase 5 — split apps into discrete tenants/VRFs (BRKDCN slide 114 ladder top)

**Today** Not on roadmap.

**Recommendation:** BRKDCN slide 114 ends the maturity ladder with "Split apps into discrete Tenants/VRFs". This is the top rung; you almost certainly will not need it. It's listed here only so the team knows it exists.

You would consider this **only** if:
- A specific app/BU requires its own RBAC boundary (separate ACI admins).
- Compliance forces hard tenant isolation (e.g., a regulated workload with separate audit scope).
- A specific app/BU requires its own routing domain that can't be expressed via ESGs and contracts.

None of these are true today. Document this as "no plan; revisit only if a triggering condition appears."

**Source:** BRKDCN slide 114.

**Open questions for the team:**
- [ ] Are any of the triggering conditions on the horizon?

**Risk if not decided:** None.

**Decision:** _________________________________________  **Re-visit:** _________

---

### G4. Decommissioning legacy AFRICOM schema

**Today** ❓ — No decommissioning plan exists.

**Recommendation:** Sketch the decommissioning sequence now so each Phase 2/3/4 step understands its role in the eventual cleanup:
1. **After Phase 2** stabilizes: legacy EPGs are still bound to ports (static bindings). V2 EPGs exist but have no endpoints. Begin port-binding migration: move port bindings from legacy EPGs to V2 EPGs in batches (this is what the `scripts/` Python tooling does).
2. **After Phase 3** stabilizes: all endpoints are in V2 EPGs and classified into V2 ESGs. Legacy EPGs in AFRICOM are empty.
3. **After F1 Option A** is done: V2 L3Outs are live, legacy AFRICOM L3Outs are no longer in path.
4. **Decommission**: empty legacy EPGs are deleted. Legacy BDs are deleted. Legacy VRFs are deleted. Legacy schema templates are deleted. Tenant `EUR` ends up containing only V2 objects.
5. **(Optional) Rename**: drop the `-V2` suffix in a final maintenance window (or keep it, per A4).

**Source:** Implicit in DESIGN's Phase 4 + F1; not currently written down anywhere.

**Open questions for the team:**
- [ ] Approve the decommissioning sequence, or modify.
- [ ] Set rough target dates so each Phase has a downstream deadline.
- [ ] Decide A4: keep `-V2` suffix forever, or rename in a post-decom window.

**Risk if not decided:** Legacy AFRICOM lives forever and the redesign never "finishes". A floating end state is harder to defend in audits than a documented one.

**Decision:** _________________________________________  **Re-visit:** _________

---

## Decision log template

Use this section to capture decisions in summary form once the team meets. One row per decided item. Items without a row are still open.

| ID | Item | Decision | Decided by | Date | Re-visit |
|----|------|----------|------------|------|----------|
| A1 | Tenant model | | | | |
| A2 | VRF count and boundaries | | | | |
| A3 | BD/EPG catalog | | | | |
| A4 | Naming convention | | | | |
| A5 | Two-Terraform-roots architecture | | | | |
| A6 | NDO orchestration model | | | | |
| A7 | VMware VMM domain | | | | |
| A8 | Access policies model | | | | |
| A9 | MCP | | | | |
| A10 | Application Profile separation | | | | |
| B1 | vzAny scope | | | | |
| B2 | Filter `Any` log directive | | | | |
| B3 | Static port bindings | | | | |
| C1 | ESG scope | | | | |
| C2 | Selector method (Phase 2) | | | | |
| C3 | Phase 2 verification | | | | |
| C4 | ESG governance | | | | |
| D1 | Phase 3 splitting axis | | | | |
| D2 | vCenter tag scheme | | | | |
| D3 | ADM procedure | | | | |
| D4 | Selector type matrix | | | | |
| D5 | Per-zone ESG naming | | | | |
| D6 | Selector ordering | | | | |
| E1 | Contract naming convention | | | | |
| E2 | Filter granularity | | | | |
| E3 | Phase 4 sequencing | | | | |
| E4 | vzAny removal procedure | | | | |
| F1 | V2 L3Out ownership | | | | |
| F2 | L3Out pattern (per-VRF) | | | | |
| F3 | External classification (ESG) | | | | |
| F4 | Route-control gotcha doc | | | | |
| F5 | BGP hardening checklist | | | | |
| G1 | nac-ndo ESG consolidation | | | | |
| G2 | IPv6 absorption | | | | |
| G3 | Phase 5 (tenant split) | | | | |
| G4 | AFRICOM decommissioning plan | | | | |

---

## Reading order suggestions for first meeting

If the team has 60-90 minutes, walk in this order:

1. **Section A (Foundations)** — confirm what is already locked. Most items will pass with no debate; flag exceptions.
2. **Section F (L3Out blueprint)** — this is the biggest open architectural decision. Resolve F1, F2, F3 before Phase 3 work starts.
3. **Section D2 (vCenter tag scheme)** — name an owner. Without this, Phase 3 is blocked regardless of tooling.
4. **Section D3 (ADM procedure)** — name an owner. Without this, Phase 4 is blocked.
5. **Section E1 (Contract naming)** — adopt the convention now while it's free.

Sections B, C, D1, D4-D6, E2-E4, G1-G4 can be deferred to a second meeting or asynchronous review in PRs.

---

*End of document.*


# ACI V2 Redesign — Executive Summary

**For:** RCC-E DC team leadership and stakeholders
**About:** Tenant `EUR` ACI redesign on the Site1/Site2 fabric pair
**Detail:** See `ACI_STRATEGY_DECISIONS.md` (37 decision items, 932 lines)
**Excluded:** firewall service graphs, K8s, AI, mainframe, F5 placement, multi-site failover

---

## What and why

We are migrating the `EUR` tenant from a network-centric layout (11 VRFs, 215 BDs, 266 VLAN-named EPGs, no security groups) to a consolidated, security-policy-aware layout (2 VRFs, 39 descriptive BDs, 39 EPGs, ESGs as the security overlay). The migration runs in-place inside the same tenant, using a `-V2` naming suffix for safe coexistence with the legacy AFRICOM schema.

The redesign aligns with Cisco's current ACI design guidance (BRKDCN-2984), the WWT/Belete recommendations from the 2025 design discussions, and the operational constraints we have today (one on-site engineer, no Tetration/CSW, NDI is the only flow-analysis tool).

## Where we are

| | Legacy AFRICOM | V2 redesign |
|---|---|---|
| Tenants | 1 (`EUR`) | 1 (same `EUR`) |
| VRFs | 11 | 2 (`VRF-AFR-DEL.Services-V2`, `VRF-DMZ-V2`) |
| BDs | 215 (`BD-V0005`…) | 39 (descriptive, e.g. `BD-AD-V2`) |
| EPGs | 266 | 39 + 3 DMZ |
| ESGs | 0 | 2 today (lift-and-shift), more planned |
| L3Outs | 13 (per-VRF, per-site) | 0 (inherit from legacy until F1 is decided) |
| Contracts | per-VRF permit-all | vzAny + permit-all (Phase 1) |
| Automation | Terraform + nac-ndo | Terraform + nac-ndo + nac-aci (two-roots split) |

**Status:** Foundations and Phase 1 are deployed. Phase 2 (lift-and-shift ESGs) is in flight. Phases 3 and 4 are designed but blocked on people/process decisions, not tooling.

## The four phases (at a glance)

1. **Phase 1 — vzAny permit-all** (today). Safety net. Everything talks to everything inside each VRF.
2. **Phase 2 — Lift-and-shift ESGs** (in flight). One big ESG per VRF (`ESG-All-Internal-V2`, `ESG-All-DMZ-V2`). vzAny stays. ESGs are observation-only.
3. **Phase 3 — Per-zone ESGs** (planned, blocked). Split the big ESGs by vCenter tag selector. vzAny still in place.
4. **Phase 4 — ESG↔ESG contracts** (future). Explicit allow-lists between specific ESGs. Drop vzAny last.

## What we need from stakeholders (5 decisions)

These are the items that the DC team cannot resolve alone. The full document tracks 37 decisions; these 5 are the gating items.

| # | Decision | Owner needed | Blocks | Recommended choice |
|---|---|---|---|---|
| 1 | **V2 L3Out ownership** — does V2 build its own L3Outs, or inherit from legacy AFRICOM forever? | Network architect + FW team | Phase 3 cleanup, AFRICOM retirement | V2 builds its own (4 L3Outs, dedicated per VRF per site) |
| 2 | **vCenter tag scheme + ownership** — who owns the `aci-zone` / `aci-tier` / `aci-app` tag values, and how are new VMs tagged? | vCenter team + Network team jointly | Phase 3 entirely | Network team owns scheme, vCenter team applies tags via existing provisioning flow |
| 3 | **Application Dependency Mapping procedure** — who runs NDI flow capture, who interviews app owners, who maintains the output? | Network team + an app-side liaison | Phase 4 entirely | Network team runs NDI; app owners called per-app on demand; output stored in Git |
| 4 | **Contract naming convention for Phase 4** — adopt now while it's free | Network team | Cleanliness of Phase 4 | Adopt the BRKDCN convention (`permit-to-<provider-ESG>` + `<protocol>-src-any-dst-<port>`) |
| 5 | **AFRICOM decommissioning end-state** — does the redesign ever "finish", and what does the final state look like? | DC management | Defining "done" | V2 fully owns the tenant; AFRICOM schema retired; `-V2` suffix kept (or renamed in a separate window) |

## What is going well

- **Direction matches current Cisco guidance** (BRKDCN-2984 maturity ladder slide 114). The repo is one rung ahead of where the 2025 design discussions explicitly authorized — and BRKDCN endorses every move.
- **Single tenant, no PBR, no service graphs, no route leaking, VMM integrated, Terraform-driven** — all five 2025 design discussions agreed on these and the repo follows them.
- **Brownfield-safe**: the `-V2` suffix means legacy and redesign coexist with zero endpoint downtime during cutover.
- **Tooling is current**: ACI 6.1(4)+ and NDO 4.2+ are deployed (the missing pieces in 2025 are now available).

## Risks worth naming

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Phase 3 stalls for lack of vCenter tag governance | High | Phase 3 cannot start | Decision #2 above |
| Phase 4 contracts written without app-flow data and break production | Medium | Outage | Decision #3 above; long Phase 2 baseline; pilot one app first |
| Legacy AFRICOM never gets decommissioned, two-headed schema permanently | Medium | Operational debt | Decision #5 above |
| `nac-ndo` upstream stays without ESG support, two-Terraform-roots split is permanent | Low | Maintenance friction | Track upstream; consolidate when it ships |
| Audit/compliance challenges vzAny+permit-all as a security posture | Low | Forced re-architecture | Document the migration plan with target dates; vzAny is explicitly the migration scaffold |

## What we are NOT asking stakeholders to decide

- The 2-VRF, 39-BD, descriptive-naming consolidation (already done; backed by BRKDCN, NextGen meeting, your DESIGN.md).
- The two-Terraform-roots Terraform split (forced by current upstream tooling; will collapse later).
- VMM integration (already deployed; universally endorsed).
- No PBR, no service graphs (universally endorsed; out of our scope anyway).

## Asks

1. **30-minute review meeting** with the DC team to walk decisions #1–#5 above.
2. **Named owners** for vCenter tag scheme (decision #2) and ADM procedure (decision #3).
3. **Sign-off** on V2 L3Out ownership (decision #1) so the cutover sequence can be planned.

---

*Prepared for stakeholder review. The full 37-decision document with rationale, source citations, and open questions is at `docs/ACI_STRATEGY_DECISIONS.md`.*

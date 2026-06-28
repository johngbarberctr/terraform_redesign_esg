# EUR Tenant -- V2 Redesign Overview

> **Note on naming.** This document describes the **V2 (consolidated) tenant
> redesign** for the `EUR` tenant. The redesign is delivered today as an
> IPv4-only schema (because that is what is being migrated off the legacy
> 11-VRF / 266-EPG layout), but the design itself is **protocol-agnostic** --
> the same BDs, EPGs, VRFs and ANPs will eventually carry both IPv4 and IPv6
> subnets (dual-stack) once the IPv6 RCC layer is folded in.
>
> **Names in this doc vs names on the wire.** The conceptual names below
> (`BD-AD`, `EPG-APP-SVR`, `VRF-EUR`, `Any_VRF-EUR`, `AppProf-NetCentric`,
> ...) are kept un-suffixed for design-readability. The actual NDO/ACI
> objects deployed by `aci-redesign/ndo/` carry a generational `-V2` suffix
> (`BD-AD-V2`, `EPG-APP-SVR-V2`, `VRF-AFR-DEL.Services-V2`, `Any_VRF-AFR-DEL.Services-V2`,
> `AppProf-NetCentric-V2`, ...). The suffix exists because the legacy
> `AFRICOM` schema (managed by `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/`) deploys
> into the **same tenant `EUR`**, and ACI requires unique object names per
> tenant. See **`DESIGN.md` -> "Naming convention"** for the full
> rationale, including why `-V2` is generational and not address-family
> specific.
>
> When you read `BD-DB-SVR` in this doc, the deployed object is
> `uni/tn-EUR/BD-DB-SVR-V2`. The mapping is mechanical: append `-V2` to
> any tenant-scoped object name.

---

## Purpose

Redesign the EUR tenant infrastructure from the legacy 11-VRF / 266-EPG
layout to a simplified 2-VRF / 39-EPG architecture that mirrors the IPv6
RCC naming structure. This consolidates routing, replaces numeric
VLAN-based names with descriptive functional names, and introduces ESGs
for future segmentation.

The first wave of the redesign carries IPv4 subnets only (the legacy
production tenant is IPv4 today). The same BDs are designed to absorb
the IPv6 RCC subnets in a follow-on wave, producing a single dual-stack
schema and allowing the legacy `AFRICOM` schema to be retired.

---

## Current State (Production)

| Attribute | Value |
|-----------|-------|
| Tenant | EUR |
| Schema | AFRICOM |
| VRFs | 11 (EUR-E, EUR-AIS, EUR-AIM, EUR-AIV, EUR-AIZ, EUR-AIG, EUR-AIP, EUR-AOV-UC-DMZ, EUR-ARMY-ENT-SVR-DMZ, EUR-GSN-Test, EUR-E catch-all) |
| Bridge Domains | 215 (numeric: BD-V0005 through BD-V2205) |
| EPGs | 266 (numeric: EPG-V0005 through EPG-V2205) |
| Contracts | Per-VRF individual contracts (no vzAny) |
| ESGs | None |
| L3Outs | 13 |
| VMM Domain | VMM1 (legacy production) |

**Problems with current design:**
- 11 VRFs were created for segmentation, but most are legacy -- the firewall handles real security boundaries, not ACI routing isolation.
- Numeric BD/EPG names (BD-V0372, EPG-V0572) give no indication of function. Operators must cross-reference alias tables to understand what a VLAN carries.
- 266 EPGs are difficult to manage, audit, and contract.
- No ESGs means no path to micro-segmentation without contracts on every EPG pair.

---

## Target State (V2 Redesign)

| Attribute | Value |
|-----------|-------|
| Tenant | EUR (unchanged -- the legacy `AFRICOM` schema also deploys into this tenant) |
| Schema | `AFRICOM-V2` (single template `Tenant_EUR_V2`) |
| VRFs | **2** -- `VRF-EUR` (internal) + `VRF-DMZ` (proxy segments). Deployed names: `VRF-AFR-DEL.Services-V2`, `VRF-DMZ-V2`. |
| Bridge Domains | **39** (descriptive: `BD-AD`, `BD-APP-SVR`, `BD-CFG-MGMT`, ...). Deployed names: same with `-V2` suffix. |
| EPGs | **39** (1:1 with BDs: `EPG-AD`, `EPG-APP-SVR`, `EPG-CFG-MGMT`, ...). Deployed names: same with `-V2` suffix. |
| Contracts | vzAny permit-all on each VRF (initial), tightened via ESGs later. Deployed names: `Any_VRF-AFR-DEL.Services-V2`, `Any_VRF-DMZ-V2`. |
| ESGs | `ESG-All-Internal-V2` (selects all 36 EPGs in `AppProf-NetCentric-V2`) + `ESG-All-DMZ-V2` (selects all 3 EPGs in `AppProf-DMZ-V2`), both under a third ANP `AppProf-AppCentric-V2`. The two ESGs land APIC-direct via the `nac-aci@0.7.0` wrapper (loaded by `apic-vmware/main.tf` from `data/nac-aci-shared/tenant-eur-esgs.nac.yaml` for both Site1 and Site2), because `nac-ndo ~> 1.2.0` and the upstream Cisco `mso` provider `~> 1.7.x` do not model `endpoint_security_groups`. vzAny+permit-all on each VRF keeps both ESGs reachability-neutral. |
| VMM Domains | **Per-fabric**: `APCG-VDS1` on Site1, `APCK-VDS1` on Site2. Each adopts the existing per-fabric VDS in vCenter (`dvs_version: unmanaged`). Replaces the legacy single shared `VMM1` domain. |
| Address families | IPv4 today; IPv6 (currently in `AFR-PROD-V6` / `AppProf-AFR-PROD-V6`) folded in later as additional subnets on the same `BD-*-V2` objects. |

---

## Architecture Diagram

> Names below are the **conceptual** (un-suffixed) names. Deployed
> objects carry the `-V2` suffix.

```
Tenant: EUR
│
├── Filter: Any (cross-referenced from AFRICOM / VRF_Template / Any -- not redefined here)
├── Contract: Any_VRF-EUR  (scope: context)              [deployed as Any_VRF-AFR-DEL.Services-V2]
├── Contract: Any_VRF-DMZ  (scope: context)              [deployed as Any_VRF-DMZ-V2]
│
├── VRF-EUR (Internal)  ─── vzAny: Any_VRF-EUR          [deployed as VRF-AFR-DEL.Services-V2]
│   │
│   ├── 36 Bridge Domains (22 with IPv4 subnets today, 14 placeholders ready for IPv6)
│   │   BD-ACAS-MGMT, BD-ACAS-SCANNERS, BD-AD, BD-ADM-DCO, BD-ADFS,
│   │   BD-APP-SVR (32 subnets), BD-BACKUP-SVR, BD-C2C-SCANNERS,
│   │   BD-CFG-MGMT (19 subnets), BD-DB-SVR (8 subnets), BD-DHCP-SVR,
│   │   BD-DNS-MGMT, BD-E911-SVR, BD-FILE-SVR, BD-FMWR-SVR, BD-GEF-MGMT,
│   │   BD-LB, BD-LMR, BD-MECM, BD-NAC, BD-NMS, BD-OCSP, BD-PATCH,
│   │   BD-PKI-SRV, BD-PRINT-SVR, BD-AFRICOM-DCO, BD-AFRICOM-DNS, BD-AFRICOM-SVR,
│   │   BD-AFRICOM-UNIX, BD-SMTP-SVR, BD-SYSLOG, BD-SYSMAN, BD-VHOST-MGMT,
│   │   BD-VVOIP-MGMT (9 subnets), BD-VVOIP-PROXY, BD-WEB-SVR (11 subnets)
│   │
│   ├── AppProf-NetCentric (36 EPGs on per-fabric VMM domains: APCG-VDS1 / APCK-VDS1)
│   │       NDO-managed via data/nac-ndo/schema-africom-v2.nac.yaml
│   │       [deployed as AppProf-NetCentric-V2]
│   └── AppProf-AppCentric / ESG-All-Internal (selects all 36 EPGs above)
│           APIC-direct via data/nac-aci-shared/tenant-eur-esgs.nac.yaml
│           (loaded by apic-vmware/ for both Site1 and Site2)
│           [deployed as AppProf-AppCentric-V2 / ESG-All-Internal-V2]
│
├── VRF-DMZ (DMZ Proxies) ─── vzAny: Any_VRF-DMZ        [deployed as VRF-DMZ-V2]
│   │
│   ├── 3 Bridge Domains
│   │   BD-D64-PROXY (placeholder), BD-FWEB-PROXY (3 subnets), BD-RWEB-PROXY (placeholder)
│   │
│   ├── AppProf-DMZ (3 EPGs on per-fabric VMM domains: APCG-VDS1 / APCK-VDS1)
│   │       NDO-managed via data/nac-ndo/schema-africom-v2.nac.yaml
│   │       [deployed as AppProf-DMZ-V2]
│   └── AppProf-AppCentric / ESG-All-DMZ (selects all 3 DMZ EPGs)
│           APIC-direct via the same data/nac-aci-shared/tenant-eur-esgs.nac.yaml
│           (one ANP, two ESGs -- one per VRF)
│           [deployed as AppProf-AppCentric-V2 / ESG-All-DMZ-V2]
│
└── AFR-PROD-V6 (IPv6) ─── still managed separately by ndo-terraform-nac (interim)
    Folds into the BD-*-V2 set above as additional subnets in a later wave.
```

---

## Key Design Decisions

### 1. Why 2 VRFs instead of 11

The legacy VRFs (EUR-E, EUR-AIS, EUR-AIM, EUR-AIV, EUR-AIZ, EUR-AIG, EUR-AIP) were created for routing isolation as a segmentation strategy. In practice, the firewall handles security enforcement at the L3Out -- the VRF boundaries add operational complexity without meaningful security value.

**VRF-EUR** consolidates all internal traffic into a single routing domain. Segmentation will be enforced by ESGs and contracts, not by routing isolation.

**VRF-DMZ** exists only for segments where ACI owns the gateway (the 139.139.x.x proxy subnets from EUR-AIP). This provides true routing isolation between DMZ proxies and internal services.

### 2. Why L2 BDs with "DMZ" in their alias stay in VRF-EUR

Several legacy BDs have "DMZ" in their alias (e.g., `Private_DMZ_Application`, `PUB-UNREST-DMZ-WEB`, `CAIR_DMZ_1_WEB`) but were in the catch-all EUR-E VRF with no subnets. These are **L2-only segments where the gateway lives on an external firewall**, not in ACI.

These stay in VRF-EUR because:
- ACI does not own the gateway for these segments -- the firewall does. The VRF only matters for routing, and these BDs have no routes.
- VRF-DMZ is reserved for segments where ACI provides the anycast gateway (the proxy subnets). Putting L2-only BDs in VRF-DMZ adds no security value.
- The firewall at the L3Out/service graph enforces the actual DMZ boundary regardless of which VRF the BD is in.
- In Phase 3 (ESG tightening), these DMZ L2 segments can be grouped into zone-specific ESGs (e.g., ESG-DMZ-Apps, ESG-DMZ-Web) for contract enforcement within VRF-EUR.

### 3. Why 39 BDs/EPGs (matching IPv6 RCC)

The IPv6 RCC design (`ndo-terraform-nac/10.52.4.96/bds_epgs.tf`) defines 39 functionally named BDs/EPGs in a single VRF with vzAny. This naming scheme replaces the numeric VLAN-based names with human-readable categories:

| Legacy (IPv4) | V2 redesign (will be dual-stack) |
|----------------|---------------------------------|
| BD-V0172, BD-V0222, BD-V0322 | **BD-AD** (Active Directory) |
| BD-V0372, BD-V0272, BD-V0572 + 36 more | **BD-APP-SVR** (Application Servers) |
| BD-V0016, BD-V0015, BD-V0017 + 37 more | **BD-CFG-MGMT** (Configuration Management) |
| BD-V0250, BD-V0350, BD-V0445 + 8 more | **BD-DB-SVR** (Database Servers) |

Each new BD absorbs all IPv4 subnets from the legacy BDs it replaces. No IP addresses change -- endpoints keep their current IPs. In the dual-stack wave, the IPv6 RCC subnets land on the same `BD-*-V2` objects as additional subnets.

### 4. Subnet consolidation -- no IP changes required

This is a **brownfield-safe** design. Every existing IPv4 subnet is preserved under the new BD naming structure. A single new BD can have multiple subnets (anycast gateways) from multiple old BDs.

Example -- BD-APP-SVR contains 32 subnets from 39 legacy BDs:
```
BD-APP-SVR (VRF-EUR):
  10.51.236.65/26    (was BD-V0572 / APCE_EUR_APPS)
  10.51.172.1/24     (was BD-V0372 / APCG_EUR_APPS)
  10.51.108.1/24     (was BD-V0272 / APCK_EUR_APPS)
  10.52.37.129/26    (was BD-V0455 / APCK_RDS)
  ... 28 more subnets
```

No host, VM, or switch needs an IP change. The ACI gateway address stays the same -- it just moves to a BD with a better name.

### 5. vzAny + ESG phased approach

| Phase | What | Security posture |
|-------|------|------------------|
| **Phase 1 (complete)** | vzAny permit-all on VRF-AFR-DEL.Services-V2 and VRF-DMZ-V2; 39 EPGs in `AppProf-NetCentric-V2` + `AppProf-DMZ-V2` (NDO-managed) | Open -- all EPGs in a VRF can communicate freely |
| **Phase 2 (in flight)** | Two lift-and-shift ESGs (`ESG-All-Internal-V2`, `ESG-All-DMZ-V2`) under `AppProf-AppCentric-V2` (APIC-direct via `nac-aci`); EPG-only selectors today; vzAny preserves reachability | Classification ready -- no policy change yet |
| **Phase 3 (future)** | Split each ESG into zone-specific groups (e.g. `ESG-AIM-V2`, `ESG-AIS-V2`, `ESG-DMZ-Apps-V2`) by adding `tag_selectors` (vCenter custom-attribute) and trimming `epg_selectors` | Segmentation by function |
| **Phase 4 (future)** | Replace VRF-level vzAny with explicit ESG-to-ESG contracts on the only flows that need to exist | Micro-segmentation |

This is progressive -- each phase adds security without breaking existing communication.

---

## BD Mapping Summary

All 215 legacy IPv4 BDs have been accounted for:

| Category | Count | Description |
|----------|-------|-------------|
| **Mapped with subnets** | 171 | Consolidated into 22 of the 39 functional BDs (110 total subnets) |
| **Mapped L2-only** | 14 | Have a clear function but no subnets (gateway on external firewall) |
| **Placeholder BDs** | 17 | IPv6-only categories with no IPv4 predecessor (new functional slots) |
| **Decommission** | 30 | 20 dead/empty + 4 deprecated + 6 temporary test BDs |
| **Total** | **215** | **0 unmatched** |

### Top consolidations by subnet count

| New BD | Subnets | Legacy BDs absorbed | Primary function |
|--------|---------|---------------------|------------------|
| BD-APP-SVR | 32 | 39 | Application servers, VDI, ITSM apps |
| BD-CFG-MGMT | 19 | 40 | Server management (OOB, inband, DRAC, IACS) |
| BD-WEB-SVR | 11 | 18 | Web frontends, ITSM web tiers |
| BD-VVOIP-MGMT | 9 | 14 | UC public/restricted, gateways, messaging |
| BD-DB-SVR | 8 | 11 | SQL/database backends |
| BD-MECM | 6 | 6 | SCCM/MECM patching infrastructure |

---

## VRF Assignment Logic

```
Is ACI the IP gateway for this segment?
├── YES (has subnet configured on the BD)
│   ├── Is it a DMZ proxy (139.139.x.x, forward/reverse/D64)?
│   │   ├── YES → VRF-DMZ
│   │   └── NO  → VRF-EUR
│   └── Done
└── NO (L2-only, gateway on firewall/router)
    └── VRF-EUR (firewall enforces DMZ boundary, ESGs handle segmentation)
```

---

## What Changes vs What Stays the Same

| Aspect | Changes | Stays the same |
|--------|---------|----------------|
| **IP addresses** | -- | All subnets preserved, no readdressing |
| **VRF count** | 11 → 2 | -- |
| **BD/EPG count** | 215/266 → 39/39 | -- |
| **BD/EPG names** | Numeric → descriptive (with `-V2` suffix on the wire) | -- |
| **Tenant name** | -- | `EUR` -- legacy `AFRICOM` and new `AFRICOM-V2` share it |
| **Contracts** | Per-EPG → vzAny + ESG | Contract model (still ACI contracts) |
| **VMM domain** | VMM1 → per-fabric `APCG-VDS1` / `APCK-VDS1` (each adopts the existing per-fabric VDS in vCenter) | Dynamic VLAN assignment from `vmm-vlan-pool` 3501-3967 |
| **L3Outs** | 13 → ~4 (production) | External routing concept |
| **Firewall** | -- | Still enforces DMZ boundaries |
| **IPv6 (AFR-PROD-V6)** | Folded into `BD-*-V2` as additional subnets in a later wave | Currently still managed separately |

---

## File Reference

| File | Purpose |
|------|---------|
| `aci-redesign/data/nac-ndo/schema-africom-v2.nac.yaml` | Source of truth (NDO layer): schema `AFRICOM-V2` / template `Tenant_EUR_V2`, VRFs, BDs, contracts, and the 2 ANPs holding the 39 EPGs (`AppProf-NetCentric-V2` + `AppProf-DMZ-V2`) |
| `aci-redesign/data/nac-aci-shared/tenant-eur-esgs.nac.yaml` | Source of truth (ESG layer): the third ANP `AppProf-AppCentric-V2` and the two Phase-2 ESGs (`ESG-All-Internal-V2`, `ESG-All-DMZ-V2`). Loaded APIC-direct by both Site1 and Site2 modules in `aci-redesign/apic-vmware/main.tf`. |
| `aci-redesign/DESIGN.md` | Design rationale + the canonical "Naming convention" section explaining `-V2`; full Phase-2 deploy playbook |
| `docs/reports/bd_mapping_analysis.txt` | Full mapping of all 215 legacy BDs to the 39 functional BDs |
| `ndo-terraform-nac/10.52.4.96/bds_epgs.tf` | IPv6 RCC design (source of the 39-BD naming structure) |
| `ndo-terraform/generate_ipv6_bindings3.py` | IPv4-to-IPv6 EPG mapping (canonical source) |
| `aci-redesign/README.md` | Lab deployment instructions and directory structure |

---

## Production Migration (Brownfield)

The lab is greenfield (built from scratch). Production requires coexistence:

| Phase | Action | Risk | Mitigation |
|-------|--------|------|------------|
| 1 | Create `VRF-AFR-DEL.Services-V2`, `VRF-DMZ-V2` alongside existing 11 VRFs | None | New VRFs are empty |
| 2 | Create 39 new BDs (`BD-*-V2`) with descriptive names | None | New BDs have no endpoints |
| 3 | Create vzAny contracts (NDO) and the lift-and-shift ESGs `ESG-All-Internal-V2` + `ESG-All-DMZ-V2` under `AppProf-AppCentric-V2` (APIC-direct via `nac-aci`) | None | Classification ready, vzAny+permit-all keeps the ESGs reachability-neutral |
| 4 | Migrate EPGs from old VRFs to `VRF-AFR-DEL.Services-V2` / `VRF-DMZ-V2` | **Brief traffic loss per subnet** | Per-subnet maintenance windows; endpoints re-learn |
| 5 | Consolidate L3Outs (13 → ~4) | **Routing re-convergence** | Coordinate with firewall/WAN teams |
| 6 | Rename EPGs/BDs from numeric to descriptive | Cosmetic only | Can be done anytime |
| 7 | Decommission old VRFs, contracts, L3Outs (and the legacy `AFRICOM` schema once empty) | None (if all migrated) | Validate no orphaned objects |

**Phase 4 is the critical step.** Moving a BD from one VRF to another causes endpoint re-learning (~seconds of traffic loss per subnet). Each subnet gets its own change window.

After cutover, the `-V2` suffix can either stay (cosmetic only) or be dropped during a per-object maintenance window. Most operators just keep `-V2`.

---

## Decommission List (30 BDs)

These legacy BDs should be removed during or after migration:

**Dead/empty (20):** BD-2250, BD-V0005, BD-V0006, BD-V0958, BD-V0970, BD-V1116, BD-V1117, BD-V1120, BD-V1140-V1149, BD-V1571, BD-V2150

**Deprecated (4):** BD-V0009 (Native VLAN), BD-V0021 (ATM -- "may need to remove"), BD-V0529 ("Remove" in alias), BD-GSN-Test

**Temporary test (6):** BD-V0020, BD-V2001, BD-V2002, BD-V2003, BD-V2004, BD-V2005 (all TMP_SATTest)

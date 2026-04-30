# EUR Tenant -- IPv4 Redesign Overview

## Purpose

Redesign the EUR tenant IPv4 infrastructure from the legacy 11-VRF / 266-EPG layout to a simplified 2-VRF / 39-EPG architecture that mirrors the IPv6 RCC naming structure. This consolidates routing, replaces numeric VLAN-based names with descriptive functional names, and introduces ESGs for future segmentation.

---

## Current State (Production)

| Attribute | Value |
|-----------|-------|
| Tenant | EUR |
| Schema | AEDCE |
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

## Target State (Redesign)

| Attribute | Value |
|-----------|-------|
| Tenant | EUR |
| VRFs | **2** -- VRF-EUR (internal) + VRF-DMZ (proxy segments) |
| Bridge Domains | **39** (descriptive: BD-AD, BD-APP-SVR, BD-CFG-MGMT, etc.) |
| EPGs | **39** (1:1 with BDs: EPG-AD, EPG-APP-SVR, EPG-CFG-MGMT, etc.) |
| Contracts | vzAny permit-all on each VRF (initial), tightened via ESGs later |
| ESGs | ESG-All-Internal-EPGs (36 EPGs) + ESG-All-DMZ-EPGs (3 EPGs) |
| VMM Domains | **Per-fabric**: `APCG-VDS1` on AEDCG, `APCK-VDS1` on AEDCK. Each adopts the existing per-fabric VDS in vCenter (`dvs_version: unmanaged`). Replaces the legacy single shared `VMM1` domain. |
| IPv6 | Unchanged -- VRF-RCC managed separately |

---

## Architecture Diagram

```
Tenant: EUR
│
├── Filter: Any (permit all, ethertype unspecified)
├── Contract: Any_VRF-EUR (scope: context)
├── Contract: Any_VRF-DMZ (scope: context)
│
├── VRF-EUR (Internal IPv4) ─── vzAny: Any_VRF-EUR
│   │
│   ├── 36 Bridge Domains (22 with IPv4 subnets, 14 placeholders)
│   │   BD-ACAS-MGMT, BD-ACAS-SCANNERS, BD-AD, BD-ADM-DCO, BD-ADFS,
│   │   BD-APP-SVR (32 subnets), BD-BACKUP-SVR, BD-C2C-SCANNERS,
│   │   BD-CFG-MGMT (19 subnets), BD-DB-SVR (8 subnets), BD-DHCP-SVR,
│   │   BD-DNS-MGMT, BD-E911-SVR, BD-FILE-SVR, BD-FMWR-SVR, BD-GEF-MGMT,
│   │   BD-LB, BD-LMR, BD-MECM, BD-NAC, BD-NMS, BD-OCSP, BD-PATCH,
│   │   BD-PKI-SRV, BD-PRINT-SVR, BD-RCC-DCO, BD-RCC-DNS, BD-RCC-SVR,
│   │   BD-RCC-UNIX, BD-SMTP-SVR, BD-SYSLOG, BD-SYSMAN, BD-VHOST-MGMT,
│   │   BD-VVOIP-MGMT (9 subnets), BD-VVOIP-PROXY, BD-WEB-SVR (11 subnets)
│   │
│   ├── AppProf-NetCentric (36 EPGs on per-fabric VMM domains: APCG-VDS1 / APCK-VDS1)
│   └── ESG-All-Internal-EPGs (selects all 36)
│
├── VRF-DMZ (DMZ Proxies) ─── vzAny: Any_VRF-DMZ
│   │
│   ├── 3 Bridge Domains
│   │   BD-D64-PROXY (placeholder), BD-FWEB-PROXY (3 subnets), BD-RWEB-PROXY (placeholder)
│   │
│   ├── AppProf-DMZ (3 EPGs on per-fabric VMM domains: APCG-VDS1 / APCK-VDS1)
│   └── ESG-All-DMZ-EPGs (selects all 3)
│
└── VRF-RCC (IPv6) ─── managed separately in ndo-terraform-nac
```

---

## Key Design Decisions

### 1. Why 2 VRFs instead of 11

The legacy VRFs (EUR-E, EUR-AIS, EUR-AIM, EUR-AIV, EUR-AIZ, EUR-AIG, EUR-AIP) were created for routing isolation as a segmentation strategy. In practice, the firewall handles security enforcement at the L3Out -- the VRF boundaries add operational complexity without meaningful security value.

**VRF-EUR** consolidates all internal IPv4 traffic into a single routing domain. Segmentation will be enforced by ESGs and contracts, not by routing isolation.

**VRF-DMZ** exists only for segments where ACI owns the gateway (the 139.139.x.x proxy subnets from EUR-AIP). This provides true routing isolation between DMZ proxies and internal services.

### 2. Why L2 BDs with "DMZ" in their alias stay in VRF-EUR

Several legacy BDs have "DMZ" in their alias (e.g., `Private_DMZ_Application`, `PUB-UNREST-DMZ-WEB`, `CAIR_DMZ_1_WEB`) but were in the catch-all EUR-E VRF with no subnets. These are **L2-only segments where the gateway lives on an external firewall**, not in ACI.

These stay in VRF-EUR because:
- ACI does not own the gateway for these segments -- the firewall does. The VRF only matters for routing, and these BDs have no routes.
- VRF-DMZ is reserved for segments where ACI provides the anycast gateway (the proxy subnets). Putting L2-only BDs in VRF-DMZ adds no security value.
- The firewall at the L3Out/service graph enforces the actual DMZ boundary regardless of which VRF the BD is in.
- In Phase 3 (ESG tightening), these DMZ L2 segments can be grouped into zone-specific ESGs (e.g., ESG-DMZ-Apps, ESG-DMZ-Web) for contract enforcement within VRF-EUR.

### 3. Why 39 BDs/EPGs (matching IPv6 RCC)

The IPv6 RCC design (`ndo-terraform-nac/136.215.4.96/bds_epgs.tf`) defines 39 functionally named BDs/EPGs in a single VRF with vzAny. This naming scheme replaces the numeric VLAN-based names with human-readable categories:

| Legacy (IPv4) | Redesign (IPv4 + IPv6) |
|----------------|------------------------|
| BD-V0172, BD-V0222, BD-V0322 | **BD-AD** (Active Directory) |
| BD-V0372, BD-V0272, BD-V0572 + 36 more | **BD-APP-SVR** (Application Servers) |
| BD-V0016, BD-V0015, BD-V0017 + 37 more | **BD-CFG-MGMT** (Configuration Management) |
| BD-V0250, BD-V0350, BD-V0445 + 8 more | **BD-DB-SVR** (Database Servers) |

Each new BD absorbs all IPv4 subnets from the legacy BDs it replaces. No IP addresses change -- endpoints keep their current IPs.

### 4. Subnet consolidation -- no IP changes required

This is a **brownfield-safe** design. Every existing IPv4 subnet is preserved under the new BD naming structure. A single new BD can have multiple subnets (anycast gateways) from multiple old BDs.

Example -- BD-APP-SVR contains 32 subnets from 39 legacy BDs:
```
BD-APP-SVR (VRF-EUR):
  155.155.236.65/26    (was BD-V0572 / APCE_EUR_APPS)
  155.155.172.1/24     (was BD-V0372 / APCG_EUR_APPS)
  155.155.108.1/24     (was BD-V0272 / APCK_EUR_APPS)
  136.215.37.129/26    (was BD-V0455 / APCK_RDS)
  ... 28 more subnets
```

No host, VM, or switch needs an IP change. The ACI gateway address stays the same -- it just moves to a BD with a better name.

### 5. vzAny + ESG phased approach

| Phase | What | Security posture |
|-------|------|------------------|
| **Phase 1 (current)** | vzAny permit-all on VRF-EUR and VRF-DMZ | Open -- all EPGs in a VRF can communicate freely |
| **Phase 2 (current)** | Single ESG per VRF grouping all EPGs | Classification ready -- no policy change yet |
| **Phase 3 (future)** | Split ESGs into zone-specific groups (ESG-AIM, ESG-AIS, ESG-DMZ-Apps, etc.) with inter-ESG contracts | Segmentation by function |
| **Phase 4 (future)** | Tighten contracts to only required flows | Micro-segmentation |

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
| **BD/EPG names** | Numeric → descriptive | -- |
| **Contracts** | Per-EPG → vzAny + ESG | Contract model (still ACI contracts) |
| **VMM domain** | VMM1 → per-fabric `APCG-VDS1` / `APCK-VDS1` (each adopts the existing per-fabric VDS in vCenter) | Dynamic VLAN assignment from `vmm-vlan-pool` 3501-3967 |
| **L3Outs** | 13 → ~4 (production) | External routing concept |
| **Firewall** | -- | Still enforces DMZ boundaries |
| **IPv6 (VRF-RCC)** | -- | Unchanged, managed separately |

---

## File Reference

| File | Purpose |
|------|---------|
| `aci-redesign/data/nac-aci-shared/tenant-epg-nac.nac.yaml` | Complete 39-BD/EPG YAML config with all 110 subnets |
| `docs/reports/bd_mapping_analysis.txt` | Full mapping of all 215 legacy BDs to the 39 functional BDs |
| `ndo-terraform-nac/136.215.4.96/bds_epgs.tf` | IPv6 RCC design (source of the 39-BD naming structure) |
| `ndo-terraform/generate_ipv6_bindings3.py` | IPv4-to-IPv6 EPG mapping (canonical source) |
| `aci-redesign/README.md` | Lab deployment instructions and directory structure |

---

## Production Migration (Brownfield)

The lab is greenfield (built from scratch). Production requires coexistence:

| Phase | Action | Risk | Mitigation |
|-------|--------|------|------------|
| 1 | Create VRF-EUR, VRF-DMZ alongside existing 11 VRFs | None | New VRFs are empty |
| 2 | Create 39 new BDs with descriptive names | None | New BDs have no endpoints |
| 3 | Create ESGs and vzAny contracts | None | Policy ready, no enforcement yet |
| 4 | Migrate EPGs from old VRFs to VRF-EUR/VRF-DMZ | **Brief traffic loss per subnet** | Per-subnet maintenance windows; endpoints re-learn |
| 5 | Consolidate L3Outs (13 → ~4) | **Routing re-convergence** | Coordinate with firewall/WAN teams |
| 6 | Rename EPGs/BDs from numeric to descriptive | Cosmetic only | Can be done anytime |
| 7 | Decommission old VRFs, contracts, L3Outs | None (if all migrated) | Validate no orphaned objects |

**Phase 4 is the critical step.** Moving a BD from one VRF to another causes endpoint re-learning (~seconds of traffic loss per subnet). Each subnet gets its own change window.

---

## Decommission List (30 BDs)

These legacy BDs should be removed during or after migration:

**Dead/empty (20):** BD-2250, BD-V0005, BD-V0006, BD-V0958, BD-V0970, BD-V1116, BD-V1117, BD-V1120, BD-V1140-V1149, BD-V1571, BD-V2150

**Deprecated (4):** BD-V0009 (Native VLAN), BD-V0021 (ATM -- "may need to remove"), BD-V0529 ("Remove" in alias), BD-GSN-Test

**Temporary test (6):** BD-V0020, BD-V2001, BD-V2002, BD-V2003, BD-V2004, BD-V2005 (all TMP_SATTest)

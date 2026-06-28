# ACI Redesign — Design Reference

This document is the **architectural reference** for the IPv4 redesign:
why the project looks the way it does, what each Terraform root owns, the
tenant model (2 VRFs, 39 BDs/EPGs), naming conventions, and migration
phases.

For deployment runbooks see:

- **Lab end-to-end**: [`../README_LAB.md`](../README_LAB.md)
- **Production cutover**: [`README.md`](README.md) (this directory)
- **Per-stack daily-driver**: each subdirectory's `README_LAB.md`

---

## Table of contents

1. [Two-root architecture](#two-root-architecture)
2. [Design decisions (why this project looks weird)](#design-decisions-why-this-project-looks-weird)
3. [Multi-fabric layout (Site1 + Site2)](#multi-fabric-layout-site1--site2)
4. [Current state — 2-VRF redesign (VRF-EUR + VRF-DMZ)](#current-state--2-vrf-redesign-vrf-eur--vrf-dmz)
5. [Design rationale](#design-rationale)
6. [Naming conventions (production-ready)](#naming-conventions-production-ready)
7. [Migration phases](#migration-phases)
8. [VMware VMM integration](#vmware-vmm-integration)
9. [What gets created](#what-gets-created)
10. [Repository layout](#repository-layout)

---

## Two-root architecture

The IPv4 redesign is split across **two Terraform roots** that each own one
control plane:

| Root              | Control plane | Owns                                                                                  |
| ----------------- | ------------- | ------------------------------------------------------------------------------------- |
| `apic-vmware/`    | APIC (per fabric, two providers via aliases) | Access/fabric policies (leaf profiles, AAEP, VPC, VLAN pools), MCP instance policy, VMware VMM domain (`vmmDomP`). |
| `ndo/`            | NDO (one Multi-Site control plane)           | Tenant `EUR`, VRFs (VRF-EUR / VRF-DMZ with vzAny), filter `Any`, contracts, all 39 stretched BDs, ANPs, EPGs, EPG-to-VMM-domain bindings. |

Why split: ACI tenant policy belongs in NDO when there's more than one site
(it's the only tool that does cross-site policy stitching cleanly), but
APIC-side fabric infrastructure (leaf profiles, VMM domain object) is per-
fabric and not modelable in NDO. So we drive each layer from the right tool
and keep the two roots independent of each other.

Cutover order on a clean lab: apply `apic-vmware/` first (with
`manage_tenants = false`, which is the default), then apply `ndo/`. NDO
references the VMM domain that `apic-vmware/` created on each APIC. The
deprecated APIC-direct tenant YAML is parked at
`data/_archive/tenant-epg-nac.nac.yaml.archived` for diff/audit only — not
loaded by either root.

---

## Design decisions (why this project looks weird)

Five structural choices in this project are non-obvious. A future maintainer
who "cleans them up" without understanding the underlying constraint will
break `terraform plan`, leak secrets to state, or get locked out of APIC.

**1. The `aci_mcp` submodule in `netascode/nac-aci` is disabled; MCP is managed in `main.tf` directly, once per fabric.**
The wrapper unconditionally creates `uni/infra/mcpInstP-default` with a
hard-coded default key of `cisco` when `manage_access_policies = true`. APIC
5.2+/6.x rejects that with `Error Code 182: Password is required for MCP
Instance Policy`. We disable it via `data/nac-aci-shared/modules.nac.yaml`
(`modules.aci_mcp: false`) and own the MCP policy with a sensitive
`var.site1_mcp_key` (resp. `var.site2_mcp_key`) per fabric, so each fabric's
key flows in from env / CI / Vault and a leak of one fabric's key does not
compromise the other.

**2. The VMM-domain YAML is rendered by a shell script before `terraform plan`, not by a `local_file` resource.**
Rendering via `local_file` was the obvious first implementation and it
fails. Any module that has `depends_on` on an un-applied resource has every
internal `for_each` / `count` deferred to apply-time, which breaks plan
against `nac-aci` with a wall of `Invalid count argument` / `Invalid
for_each argument` errors. Moving the render step *outside* Terraform (via
`scripts/render-vmm-yaml.sh`, orchestrated by the `Makefile` locally and by
`.gitlab-ci.yml` in CI) makes the rendered YAML a static input available at
plan time.

**3. APIC passwords and MCP keys are NOT declared in `terraform.tfvars`.**
Terraform variable precedence puts `terraform.tfvars` *above* `TF_VAR_*`
environment variables. If the file declares `site1_apic_password = ""`
(even empty), the env var is silently ignored and `terraform plan` fails
with `Authentication details not provided`. Leaving the slot undeclared in
the file lets the env var win for both fabrics' four secret variables
(`site1_apic_password`, `site2_apic_password`, `site1_mcp_key`,
`site2_mcp_key`), which is the pattern Stage 2 (GitLab masked CI variables)
and Stage 3 (Vault data source) both rely on.

**4. The five vCenter values are NOT Terraform variables.**
They're consumed directly by `scripts/render-vmm-yaml.sh` from
`TF_VAR_vcenter_*` env vars and substituted into the template. By design
they never become Terraform variables, never enter the state file, and
never appear in plan output. This is what lets us keep the vCenter service-
account password out of both source and state — rotating it is `export
TF_VAR_vcenter_password='...' && make plan`.

**5. `data/` is split shared / per-fabric, with both Site1 and Site2 wired up in the same Terraform root via provider aliases. Tenant content lives in `data/nac-ndo/`, not `data/nac-aci-shared/`.**
The `netascode/nac-aci` module deep-merges every YAML under every
`yaml_directories` entry. Per-fabric *infrastructure* policy — leaf-and-
port access policies, AAEP, VPC policy group, the rendered VMM-domain YAML
— lives in `data/nac-aci-<fabric>/` and `data/nac-aci-<fabric>-rendered/`.
The shared `data/nac-aci-shared/` directory now holds only
`modules.nac.yaml` (which disables the wrapper's MCP sub-module). Tenant
intent (VRFs, BDs, EPGs, contracts) moved to `data/nac-ndo/` and is
consumed by the sister `ndo/` Terraform root, not by `apic-vmware/`. Two
providers (default `aci` = Site1, aliased `aci.site2` = Site2) and four
resource blocks (two module + two MCP per fabric) push the per-fabric
infrastructure design to both APICs in one `terraform plan`.

---

## Multi-fabric layout (Site1 + Site2)

Both fabrics are wired up in the `apic-vmware/` Terraform root. Site1 is the
lab control fabric (`https://198.18.134.253`), Site2 is the second lab
fabric (`https://198.18.134.254`). The same shared tenant design lands on
both. Production promotion flips the URLs in `terraform.tfvars` and the
corresponding GitLab CI masked variables; no code change.

### Layout today

```
data/
├── nac-aci-shared/             cross-fabric APIC-direct policy
│   └── modules.nac.yaml          turns off the wrapper's aci_mcp submodule
│                                  (tenant content moved to data/nac-ndo/)
├── nac-ndo/                    NDO-managed tenant policy (consumed by ndo/ root)
│   ├── tenant.nac.yaml           stub: EUR is referenced, not created
│   └── schema-africom-v2.nac.yaml  schema AFRICOM-V2 / template Tenant_EUR_V2
├── _archive/                   deprecated YAMLs (reference only)
│   └── tenant-epg-nac.nac.yaml.archived
├── nac-aci-site1/              Site1-only access/fabric policies
│   └── access-policies.nac.yaml  VLAN pool 3501-3967, AAEP, leaf 101/102 profiles, VPC PG
├── nac-aci-site1-rendered/     gitignored; rebuilt by `render-vmm-yaml.sh site1`
│   └── vmm-domain.nac.yaml       VMware VMM domain w/ vCenter creds substituted in
├── nac-aci-site2/              Site2-only access/fabric policies
│   └── access-policies.nac.yaml  same shape as Site1; leaf nodes 119+191 (non-contiguous)
└── nac-aci-site2-rendered/     gitignored; rebuilt by `render-vmm-yaml.sh site2`
    └── vmm-domain.nac.yaml       same template, same vCenter (today), per-fabric output
```

`apic-vmware/main.tf` declares four module blocks plus two `moved {}`
blocks for state migration:

| Module | Provider | YAML dirs | What it owns |
|---|---|---|---|
| `module.aci_site1` | default `aci` | shared + site1 + site1-rendered | Site1 tenant + access/fabric/VMM policy |
| `module.aci_mcp_site1` | default `aci` | n/a (HCL only, key from `var.site1_mcp_key`) | Site1 MCP Instance Policy |
| `module.aci_site2` | `aci.site2` (aliased) | shared + site2 + site2-rendered | Site2 tenant + access/fabric/VMM policy |
| `module.aci_mcp_site2` | `aci.site2` (aliased) | n/a (HCL only, key from `var.site2_mcp_key`) | Site2 MCP Instance Policy |

The `moved {}` blocks rename the previous monolithic `module.aci` /
`module.aci_mcp` to their Site1-suffixed names. Terraform applies these as
in-place state moves; existing Site1 state does not see a destroy/recreate
or a provider reassignment because the default unaliased provider FQN stays
the same.

### Why a single Terraform root, not two

A natural reflex is "one fabric = one Terraform root", but here that buys
nothing and costs a lot:

- The shared tenant design has to be authored once and deployed twice. Two
  roots means either symlinks (fragile) or a second copy (drift). One root
  with shared+per-fabric data dirs gives one source of truth.
- A `make plan` that produces a single combined plan for both fabrics is
  dramatically easier to review than two plans you have to mentally diff.
- State stays simple: each module's resources are scoped to its provider,
  so Site1 resources live under `module.aci_site1.*` /
  `module.aci_mcp_site1.*` and Site2 under `module.aci_site2.*` /
  `module.aci_mcp_site2.*`. No state-file gymnastics.
- NDO orchestrates production multi-site policy already; the per-fabric
  work this project does is **only** what NDO can't push (access/fabric
  policies, MCP, VMM). That set is small enough that splitting it across
  two roots is overkill.

### Lab → production promotion

The recommended path is partial-fabric apply via `-target`:

1. **Validate Site1 in lab** as you do today: `make plan && make apply-site1`
   against the lab Site1 APIC.
2. **Validate Site2 in lab** independently: `make apply-site2`. Site2 leaf
   node IDs in `data/nac-aci-site2/access-policies.nac.yaml` are currently
   119 and 191 (non-contiguous, so two single-node `node_blocks`). Re-check
   those IDs whenever the lab gets recabled and confirm them against the
   production Site2 fabric before any production apply.
3. **Promote to production** by changing `site1_apic_url` / `site2_apic_url`
   in `terraform.tfvars` and the corresponding `Site1_APIC_*` /
   `Site2_APIC_*` GitLab CI masked variables. `terraform.tfvars` is
   gitignored, so the lab values stay local.

---

## Current state — 2-VRF redesign (VRF-AFR-DEL.Services-V2 + VRF-DMZ-V2)

The active deployment implements a **2-VRF architecture** replacing the
legacy 11-VRF layout. All internal EPGs consolidate into `VRF-AFR-DEL.Services-V2`,
DMZ EPGs go into `VRF-DMZ-V2`, and IPv6 stays in `AFR-PROD-V6` (managed
separately). ESGs group EPGs for future contract tightening; vzAny permits
all traffic within each VRF initially.

> **About the `-V2` suffix.** Every tenant-scoped object in this redesign
> (BDs, EPGs, VRFs, contracts, ANPs) carries a `-V2` suffix. See
> [Naming convention](#naming-convention) for the rationale and the
> commitment that the suffix is generational, not address-family.

### What gets deployed

39 BDs/EPGs matching the IPv6 RCC naming structure (with the `-V2` suffix
for parallel coexistence with AFRICOM — see [Naming convention](#naming-convention)),
with legacy IPv4 subnets consolidated under each functional BD. Each new BD
inherits all IPv4 subnets from the old numeric BDs it replaces (per
`docs/reports/bd_mapping_analysis.txt`). 18 BDs are placeholders with no
legacy IPv4 predecessor (they will become dual-stack from day one when IPv6
prefixes are added).

```
Tenant: EUR
├── Filter: Any (cross-ref to AFRICOM/VRF_Template/Any -- not redefined here)
├── Contract: Any_VRF-AFR-DEL.Services-V2 (scope: context)
├── Contract: Any_VRF-DMZ-V2 (scope: context)
│
├── VRF-AFR-DEL.Services-V2 (Internal) -- 36 BDs / 36 EPGs
│   ├── vzAny: Any_VRF-AFR-DEL.Services-V2 (provider + consumer)
│   ├── BD-ACAS-MGMT-V2      (placeholder)     → EPG-ACAS-MGMT-V2
│   ├── BD-ACAS-SCANNERS-V2  (2 subnets)       → EPG-ACAS-SCANNERS-V2
│   ├── BD-AD-V2             (3 subnets)       → EPG-AD-V2
│   ├── BD-ADM-DCO-V2        (1 subnet)        → EPG-ADM-DCO-V2
│   ├── BD-ADFS-V2           (placeholder)     → EPG-ADFS-V2
│   ├── BD-APP-SVR-V2        (32 subnets)      → EPG-APP-SVR-V2
│   ├── BD-BACKUP-SVR-V2     (4 subnets)       → EPG-BACKUP-SVR-V2
│   ├── BD-C2C-SCANNERS-V2   (placeholder)     → EPG-C2C-SCANNERS-V2
│   ├── BD-CFG-MGMT-V2       (19 subnets)      → EPG-CFG-MGMT-V2
│   ├── BD-DB-SVR-V2         (8 subnets)       → EPG-DB-SVR-V2
│   ├── BD-DHCP-SVR-V2       (placeholder)     → EPG-DHCP-SVR-V2
│   ├── BD-DNS-MGMT-V2       (L2-only, 0 subs) → EPG-DNS-MGMT-V2
│   ├── BD-E911-SVR-V2       (placeholder)     → EPG-E911-SVR-V2
│   ├── BD-FILE-SVR-V2       (3 subnets)       → EPG-FILE-SVR-V2
│   ├── BD-FMWR-SVR-V2       (placeholder)     → EPG-FMWR-SVR-V2
│   ├── BD-GEF-MGMT-V2       (L2-only, 0 subs) → EPG-GEF-MGMT-V2
│   ├── BD-LB-V2             (3 subnets)       → EPG-LB-V2
│   ├── BD-LMR-V2            (placeholder)     → EPG-LMR-V2
│   ├── BD-MECM-V2           (6 subnets)       → EPG-MECM-V2
│   ├── BD-NAC-V2            (placeholder)     → EPG-NAC-V2
│   ├── BD-NMS-V2            (1 subnet)        → EPG-NMS-V2
│   ├── BD-OCSP-V2           (placeholder)     → EPG-OCSP-V2
│   ├── BD-PATCH-V2          (1 subnet)        → EPG-PATCH-V2
│   ├── BD-PKI-SRV-V2        (1 subnet)        → EPG-PKI-SRV-V2
│   ├── BD-PRINT-SVR-V2      (placeholder)     → EPG-PRINT-SVR-V2
│   ├── BD-AFRICOM-DCO-V2        (placeholder)     → EPG-AFRICOM-DCO-V2
│   ├── BD-AFRICOM-DNS-V2        (placeholder)     → EPG-AFRICOM-DNS-V2
│   ├── BD-AFRICOM-SVR-V2        (placeholder)     → EPG-AFRICOM-SVR-V2
│   ├── BD-AFRICOM-UNIX-V2       (placeholder)     → EPG-AFRICOM-UNIX-V2
│   ├── BD-SMTP-SVR-V2       (placeholder)     → EPG-SMTP-SVR-V2
│   ├── BD-SYSLOG-V2         (3 subnets)       → EPG-SYSLOG-V2
│   ├── BD-SYSMAN-V2         (placeholder)     → EPG-SYSMAN-V2
│   ├── BD-VHOST-MGMT-V2     (1 subnet)        → EPG-VHOST-MGMT-V2
│   ├── BD-VVOIP-MGMT-V2     (9 subnets)       → EPG-VVOIP-MGMT-V2
│   ├── BD-VVOIP-PROXY-V2    (1 subnet)        → EPG-VVOIP-PROXY-V2
│   └── BD-WEB-SVR-V2        (11 subnets)      → EPG-WEB-SVR-V2
│
├── VRF-DMZ-V2 (DMZ -- routing-isolated from internal) -- 3 BDs / 3 EPGs
│   ├── vzAny: Any_VRF-DMZ-V2 (provider + consumer)
│   ├── BD-D64-PROXY-V2      (placeholder)     → EPG-D64-PROXY-V2
│   ├── BD-FWEB-PROXY-V2     (3 subnets)       → EPG-FWEB-PROXY-V2
│   └── BD-RWEB-PROXY-V2     (placeholder)     → EPG-RWEB-PROXY-V2
│
├── AppProf-NetCentric-V2  (36 internal EPGs on per-fabric VMM domains: APCG-VDS1, APCK-VDS1)
│                          NDO-managed via data/nac-ndo/schema-africom-v2.nac.yaml
├── AppProf-DMZ-V2         (3 DMZ EPGs on per-fabric VMM domains: APCG-VDS1, APCK-VDS1)
│                          NDO-managed via data/nac-ndo/schema-africom-v2.nac.yaml
└── AppProf-AppCentric-V2  (Phase-2 ESG layer -- 0 EPGs, 2 ESGs)
                           APIC-direct via data/nac-aci-shared/tenant-eur-esgs.nac.yaml
                           loaded by both Site1 and Site2 modules in apic-vmware/main.tf
                           ├── ESG-All-Internal-V2  (VRF-AFR-DEL.Services-V2 -- selects all 36 EPGs in AppProf-NetCentric-V2)
                           └── ESG-All-DMZ-V2       (VRF-DMZ-V2 -- selects all 3 EPGs in AppProf-DMZ-V2)

# Phase 3 (future): split each ESG into per-zone ESGs (e.g. ESG-AIM-V2,
# ESG-AIS-V2, ESG-DMZ-Web-V2, ESG-DMZ-Apps-V2) by adding tag_selectors and
# trimming epg_selectors. See Migration phases below.
```

**Subnet consolidation totals**: All 215 legacy IPv4 BDs are accounted for:

- **22 BDs** have IPv4 subnets (110 total subnets from 171 mapped legacy BDs)
- **17 BDs** are placeholders (IPv6-only categories with no IPv4 predecessor)
- **14 legacy BDs** are L2-only (mapped by function, no subnets — gateway on external firewall)
- **30 legacy BDs** are decommission candidates (20 dead + 4 deprecated + 6 temp test)
- **0 unmatched**

---

## Design rationale

| Decision | Why |
|----------|-----|
| **2 VRFs instead of 11** | Legacy VRFs (EUR-E, EUR-AIS, EUR-AIM, etc.) provided segmentation via routing isolation. ESGs now handle segmentation with contracts, so only Internal vs DMZ routing isolation is needed. |
| **VRF-EUR (internal)** | Consolidates EUR-E (101 EPGs), EUR-AIS (132), EUR-AIM (15), EUR-AIV (12), EUR-AIZ (11), EUR-AIG (1), EUR-AIP (4), EUR-GSN-Test (1) = ~276 EPGs. |
| **VRF-DMZ** | Keeps EUR-AOV-UC-DMZ and EUR-ARMY-ENT-SVR-DMZ routing-isolated from internal. DMZ traffic must never share a routing table with internal. |
| **AFR-PROD-V6 (IPv6)** | Unchanged. Managed separately in `~/DC/ACI/terraform-esg/ndo-terraform-ipv6/`. |
| **Descriptive naming** | `BD-DNS-MGMT` / `EPG-DNS-MGMT` replaces numeric `BD-V0005` / `EPG-V0005`. Matches IPv6 RCC naming style. |
| **vzAny permit-all** | Initial state — everything communicates. ESGs provide classification for progressive tightening. |
| **L3Outs** | Production consolidates from 13 L3Outs to ~4 (1 internal + 1 DMZ per site). Lab does not deploy L3Outs. |

---

## Naming convention

Every tenant-scoped object in this redesign carries a `-V2` suffix. This
section explains why, what's affected, and what happens at cutover.

### Why `-V2`

The legacy `AFRICOM` schema (managed by `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/`)
deploys to the same ACI tenant `EUR` and is **already in production**. ACI
enforces unique object names per tenant: a BD has exactly one DN
(`uni/tn-EUR/BD-foo`) and two NDO templates cannot both own that DN — NDO
will refuse the deploy of the second one with
`Duplicate name for different objects in different templates is not allowed`.

This is not an NDO/NaC quirk. It's an ACI data-model constraint. Same
tenant + same name + two parallel schemas is impossible.

The redesign needs to coexist with `AFRICOM` for a long parallel period before
cutover, so distinct names are mandatory. The two viable options were:

- **Suffix the redesign objects** (chosen): one tenant, two name families
  side-by-side. Cutover is endpoint-by-endpoint within `EUR` — a
  vMotion-friendly BD-to-BD migration with one set of L3Outs.
- Different tenant (e.g. `EUR-V2`): names stay clean, but cutover means
  cross-tenant L3Outs/contracts/ESGs throughout the parallel period and
  either an awkward permanent tenant name or a second migration to fold
  back into `EUR`.

### Why `-V2`, specifically not `-IPv4`

The end-state of the V2 model is **dual-stack BDs** (a single ACI BD
carrying both IPv4 and IPv6 subnets — the standard ACI 5.x+ pattern). The
schema's `IPv4` working name was true during early design but becomes
misleading the moment the first IPv6 subnet lands on a V2 BD. `-V2` is
generational and protocol-agnostic; if a V3 redesign is ever needed, the
convention extends without ambiguity.

`-V2` deliberately avoids:

- `-IPv4`, `-V4`, `-4`, `-IP` — would lock the name to one address family.
- `-NEW`, `-N`, `-NG` — decay quickly; "new" stops being true after cutover.
- `-TEST`, `-LAB`, `-STAGE` — production deploys this; the marker would lie.
- `-ESG` — confusing because ESG is also an ACI object class. A BD named
  `BD-foo-ESG` reads like the BD itself is an ESG.
- Date-based markers (`-2026`) — age immediately.

### What carries the suffix

| Object class | Convention | Example |
|---|---|---|
| Schema | `AFRICOM-V2` | `AFRICOM-V2` |
| Template | `Tenant_EUR_V2` | `Tenant_EUR_V2` |
| ACI tenant | **unchanged** (`EUR`) | `EUR` |
| VRF (internal) | `VRF-AFR-DEL.Services-V2` | `VRF-AFR-DEL.Services-V2` |
| VRF (DMZ) | `VRF-DMZ-V2` | `VRF-DMZ-V2` |
| VRF (IPv6) | `AFR-PROD-V6` (legacy, unchanged) | `AFR-PROD-V6` |
| Contract | `Any_<VRF>-V2` | `Any_VRF-AFR-DEL.Services-V2`, `Any_VRF-DMZ-V2` |
| Filter | `Any` (cross-ref to `AFRICOM/VRF_Template`, **not redefined**) | `Any` |
| BD | `BD-<function>-V2` | `BD-DNS-MGMT-V2`, `BD-DB-SVR-V2` |
| EPG | `EPG-<function>-V2` | `EPG-DNS-MGMT-V2`, `EPG-DB-SVR-V2` |
| App Profile (internal EPGs, NDO-managed) | `AppProf-NetCentric-V2` | `AppProf-NetCentric-V2` |
| App Profile (DMZ EPGs, NDO-managed) | `AppProf-DMZ-V2` | `AppProf-DMZ-V2` |
| App Profile (ESG container, APIC-direct via `nac-aci`) | `AppProf-AppCentric-V2` | `AppProf-AppCentric-V2` |
| ESG (Phase 2, lift-and-shift) | `ESG-All-<scope>-V2` | `ESG-All-Internal-V2`, `ESG-All-DMZ-V2` |
| ESG (Phase 3, per-zone splits) | `ESG-<zone>-V2` | `ESG-AIM-V2`, `ESG-DMZ-Web-V2` |

### What does NOT carry the suffix

- The ACI tenant `EUR` itself — `tenant: EUR` in the YAML stays as `EUR`.
  Suffixing the tenant would force a tenant-rename which is destructive.
- Filter `Any` — referenced cross-schema from `AFRICOM / VRF_Template`, not
  redefined in the V2 schema, so there's nothing to collide.
- Sites `Site1` / `Site2`, VMM domains `APCG-VDS1` / `APCK-VDS1`, and
  anything else that lives outside the `uni/tn-EUR/...` namespace.

### What happens at cutover

When the legacy AFRICOM schema is decommissioned (months out, see
[Migration phases](#migration-phases)), each `-V2` object can either:

- **Stay suffixed** (the path of least resistance — cosmetic only, zero
  downtime). Most operators take this option.
- **Be renamed to drop the suffix** (one BD/EPG at a time, in a per-object
  maintenance window — each rename is destroy+recreate of that one object,
  carrying a brief drop on its traffic).

Either choice is reversible at any point; pick later, not now.

### Defensive use of the suffix

Apply the suffix to **all** tenant-scoped V2 objects, not just the ones
currently colliding with AFRICOM. Today the YAML-only collision is BDs only,
but anyone adding a `VRF-EUR` or `Any_VRF-EUR` to AFRICOM in the future
would re-trigger the same class of error. Consistent suffixing eliminates
that whole future failure mode.

---

## Migration phases

The **lab is greenfield** — built from scratch to validate the target
design. **Production is brownfield** — 266 EPGs across 11 VRFs with live
traffic. Production migration requires coexistence, not a rebuild.

### Lab (greenfield)

| Phase | What | Status |
|-------|------|--------|
| 1 | Base build — 2 VRFs, 39 BDs (with consolidated IPv4 subnets), 39 EPGs in `AppProf-NetCentric-V2` + `AppProf-DMZ-V2`, VMM domain, vzAny+permit-all — NDO-managed via schema `AFRICOM-V2` / template `Tenant_EUR_V2` | **Complete** |
| 2 | Lift-and-shift ESGs grouping every EPG per VRF: `ESG-All-Internal-V2` (selects all 36 EPGs in `AppProf-NetCentric-V2`) and `ESG-All-DMZ-V2` (selects all 3 EPGs in `AppProf-DMZ-V2`), both under the new `AppProf-AppCentric-V2` ANP. APIC-direct via `nac-aci@0.7.0` (loaded from `data/nac-aci-shared/tenant-eur-esgs.nac.yaml` by `apic-vmware/main.tf` for both Site1 and Site2). vzAny+permit-all on each VRF keeps reachability identical. EPG-only selectors for now. | **In flight** — see [Phase 2 deploy playbook](#phase-2-deploy-playbook) below |
| 3 | Split each Phase-2 ESG into per-zone ESGs (e.g. `ESG-AIM-V2`, `ESG-AIS-V2`, `ESG-DMZ-Web-V2`, `ESG-DMZ-Apps-V2`) by adding `tag_selectors` (vCenter custom-attribute → ACI tag) and trimming the matching `epg_selectors`. Open question: tag scheme + ownership (vCenter team vs ACI team). | Future |
| 4 | Replace VRF-level vzAny with explicit ESG-to-ESG contracts on the only flows that need to exist; remove `vzany: true` on each VRF last | Future — micro-segmentation |

#### Phase 2 deploy playbook

Phase 2 is split into three small, independently-reversible steps so a failure of any one leaves the previous step in a known-good state:

| Step | What | Reversible by |
|---|---|---|
| 2A: Stage objects | Apply `apic-vmware/` after the NDO Deploy completes the EPG creation. The two ESGs land on each APIC under `AppProf-AppCentric-V2` but with `epg_selectors` only — endpoints are still classified by their original EPG and reach each other via vzAny. No traffic change. | `terraform destroy -target=...` on the two ESGs and the `AppProf-AppCentric-V2` ANP |
| 2B: Verify classification | APIC GUI on each fabric: `Tenants → EUR → Application Profiles → AppProf-AppCentric-V2 → ESGs → ESG-All-Internal-V2/ESG-All-DMZ-V2 → Operational → Endpoints` should list the same endpoints as the corresponding EPGs sum. Spot-check 2-3 endpoints — they should appear under both an EPG (under `AppProf-NetCentric-V2`/`AppProf-DMZ-V2`) and an ESG (under `AppProf-AppCentric-V2`). | (verification only) |
| 2C: Document the membership | Snapshot the per-ESG endpoint list as the baseline for the Phase-3 zone-split design. Open the Phase-3 design ticket. | (documentation only) |

Phase 2 deliberately does **not** change any contract relationships. The ESGs are observability/classification overlays at this stage; vzAny still does all the actual permit work on each VRF.

### Production (brownfield)

Existing 11 VRFs and 266 EPGs cannot be deleted and rebuilt. The migration
runs in parallel with live traffic:

| Phase | What | Key consideration |
|-------|------|-------------------|
| 1 | Create VRF-EUR and VRF-DMZ alongside existing VRFs | New VRFs coexist with old ones; no traffic impact |
| 2 | Create new BDs with descriptive names in VRF-EUR/VRF-DMZ | Old BDs remain operational; new BDs have no endpoints yet |
| 3 | Create vzAny contracts on VRF-AFR-DEL.Services-V2/VRF-DMZ-V2 (NDO) and the lift-and-shift ESGs in `AppProf-AppCentric-V2` (APIC-direct via `nac-aci`) | Security classification ready before any endpoints move; vzAny+permit-all keeps the ESGs reachability-neutral |
| 4 | Migrate EPGs one-at-a-time from old VRFs to new VRFs | Move BD from old VRF to new VRF; endpoints re-learn. Schedule per-subnet maintenance windows |
| 5 | Consolidate L3Outs (13 → ~4) | Requires routing re-convergence; coordinate with firewall/WAN teams |
| 6 | Rename EPGs/BDs from numeric to descriptive | Can be done during or after VRF migration |
| 7 | Decommission old VRFs, contracts, and L3Outs | Only after all EPGs have been migrated and validated |

**Risk areas**: BD VRF reassignment causes endpoint re-learning (brief
traffic loss per subnet). L3Out consolidation affects external routing.
Plan per-subnet change windows.

---

## VMware VMM integration

VMM integration uses dynamic VLAN assignment from pool **3501-3967**
(avoids IPv6 range 3001-3500 and ACI reserved 3968-4095). When an EPG is
bound to the VMM domain, ACI auto-assigns a VLAN from this pool and creates
a port group on the VDS in vCenter.

### VLAN strategy

| Range | Use | Allocation |
|-------|-----|------------|
| 3001-3500 | IPv6 RCC EPGs (existing static) | Static |
| **3501-3967** | **VMM domain (IPv4 EPGs)** | **Dynamic** |
| 3968-4095 | ACI reserved (do not use) | N/A |

### Production config (UCS-FI direct attach via vPC)

UCS Fabric Interconnects (FIs) replace the legacy N5Ks. Each FI is attached to
the fabric as a **real vPC, dual-homed across leaves 101 + 102**: `VPC_FI-A` on
eth1/6 (to UCS FI-A) and `VPC_FI-B` on eth1/7 (to UCS FI-B). Only eth1/6-7
connect to the FIs — ESXi hosts attach behind the FIs, not directly to the
leaves, so there are no host ports on the leaves. The lab and prod data dirs are
kept separate but are **identical in design**; only environment values
(APIC / vCenter / NDO IPs and credentials) differ, via tfvars / CI variables.

| Fabric | Lab data dir (consumed by `apic-vmware/`) | Prod data dir (consumed by `apic-vmware-prod/`) |
|--------|--------------------------------------------|-------------------------------------------------|
| Site1 (Kelley)  | `data/nac-aci-site1/`            | `data/nac-aci-site1-prod/`                      |
| Site2 (Del Din) | `data/nac-aci-site2/`            | `data/nac-aci-site2-prod/`                      |

Both lab and prod dirs define the same objects:

| Object | Notes |
|--------|-------|
| `fi-static-vlan-pool` | Static VLAN pool, 213 distinct VLANs in 93 contiguous ranges — the union of every VLAN in production NDO schema `AFRICOM / AppProf-NetCentric` (sourced live). Both sites use the same union for symmetry. |
| `phys-fi-domain` | Physical domain attached to `fi-static-vlan-pool` for non-VMM / bare-metal workloads riding the FI uplinks. |
| `fi-aaep` | Carries BOTH the per-fabric VMM domain (so VM traffic via the VDS reaches ESXi behind the FIs over `VPC_FI-A`/`VPC_FI-B`) AND `phys-fi-domain` (for static bare-metal VLANs). `infra_vlan: true` so ESXi VTEPs work for OpFlex. |
| `VPC_FI-A`, `VPC_FI-B` | Real vPCs (`type: vpc`, LACP active) dual-homed across leaves 101 + 102. AAEP = `fi-aaep`. |
| `leaf-101-102-intprof`, `leaf-101-102-prof` | One shared interface profile applied to the 101/102 switch profile; its `fi-a-uplink` (eth1/6) and `fi-b-uplink` (eth1/7) selectors form a vPC per FI across both leaves. No host ports on the leaves (eth1/1-5, 1/8-48 reserved). |

NDO schema `data/nac-ndo/schema-africom-v2.nac.yaml` is shared between lab
and prod — there is one schema definition because the EPG model itself is
identical; only the underlying APIC access policy differs. EPGs bind to the
per-fabric VMM domains (`Kelley-VDS1`, `Del-Din-VDS1`) at the site-local level
inside the schema (all existing EPGs are VMM-bound; static-path bindings are
reserved for bare-metal only).

Cutover sequence for prod (when the prod Terraform root is in place):
`apic-vmware-prod/` apply (creates fi-aaep, VPC_FI-A/B, static pool; references
the existing VMM domain) → ESX admin moves the FI uplinks onto `VPC_FI-A` /
`VPC_FI-B` → `ndo/` apply (binds EPGs to per-fabric VMM domains) → APIC
dynamically allocates VLANs from `vmm-vlan-pool` for VMM EPGs and pushes
port-groups onto the existing per-fabric VDS in vCenter.

---

## What gets created

`apic-vmware/` creates only the **APIC-direct** stack on BOTH fabrics:
access/fabric policies, MCP Instance Policy, and the VMware VMM domain.
The two tables below describe what `apic-vmware/` lands on each APIC.

`ndo/` creates the **tenant policy** in NDO (schema `AFRICOM-V2`, template
`Tenant_EUR_V2`). Nothing reaches the APICs from the NDO Terraform until
the operator clicks **Deploy to sites** in the NDO UI — because
`deploy_templates = false` is set in `ndo/main.tf`. See
[`../README_LAB.md`](../README_LAB.md) Phase 4 for the click-to-deploy
sequence.

### Access & fabric policies — Site1 (`module.aci_site1` + `module.aci_mcp_site1`)

| ACI Object | File | Description |
|------------|------|-------------|
| VLAN Pool | `nac-aci-site1/access-policies.nac.yaml` | `vmm-vlan-pool` (dynamic, 3501-3967) |
| CDP Policy | `nac-aci-site1/access-policies.nac.yaml` | `cdp-enabled` |
| LLDP Policy | `nac-aci-site1/access-policies.nac.yaml` | `lldp-enabled` (`admin_rx_state: true` + `admin_tx_state: true`) |
| Port Channel Policy | `nac-aci-site1/access-policies.nac.yaml` | `mac-pinning` (mode `mac-pin`; LACP LAG / `lacpLagPol`) |
| Link Level Policy | `nac-aci-site1/access-policies.nac.yaml` | `10G` |
| AAEP | `nac-aci-site1/access-policies.nac.yaml` | `vmm-aaep` linked to VMM domain |
| VPC Interface Policy Group | `nac-aci-site1/access-policies.nac.yaml` | `vpc-vmm-hosts` |
| Leaf Interface Profile | `nac-aci-site1/access-policies.nac.yaml` | `leaf-152-153-intprof` (ports 1-48) |
| Leaf Switch Profile | `nac-aci-site1/access-policies.nac.yaml` | `leaf-152-153-prof` (nodes 152-153, contiguous range) |
| VMware VMM Domain | `nac-aci-site1-rendered/vmm-domain.nac.yaml` | `APCG-VDS1` (read-write, adopts the existing per-fabric VDS in vCenter) |
| vCenter Controller | `nac-aci-site1-rendered/vmm-domain.nac.yaml` | `vcenter01` with credential policy |
| Virtual Distributed Switch | `nac-aci-site1-rendered/vmm-domain.nac.yaml` | Adopted from vCenter via `dvs_version: unmanaged` |
| MCP Instance Policy | `apic-vmware/main.tf` (`module.aci_mcp_site1`) | `default` w/ key from `TF_VAR_site1_mcp_key` |

### Access & fabric policies — Site2 (`module.aci_site2` + `module.aci_mcp_site2`)

Same object shape as Site1 but read from `nac-aci-site2/` and pushed via
the aliased `aci.site2` provider. Site2 leaf nodes are 119 and 191 (non-
contiguous, so the switch profile uses two single-node `node_blocks` rather
than a `from`/`to` range).

| ACI Object | File | Description |
|------------|------|-------------|
| VLAN Pool / CDP / LLDP / Port-Channel / LinkLevel / AAEP / VPC PG | `nac-aci-site2/access-policies.nac.yaml` | identical names + values to Site1 (names are scoped per-APIC, so this is safe) |
| Leaf Interface Profile | `nac-aci-site2/access-policies.nac.yaml` | `leaf-119-191-intprof` (ports 1-48) |
| Leaf Switch Profile | `nac-aci-site2/access-policies.nac.yaml` | `leaf-119-191-prof` (nodes 119 + 191, two single-node node_blocks) |
| VMware VMM Domain / vCenter / VDS / Uplinks | `nac-aci-site2-rendered/vmm-domain.nac.yaml` | `APCK-VDS1` adopting the per-fabric VDS for Site2 |
| MCP Instance Policy | `apic-vmware/main.tf` (`module.aci_mcp_site2`) | `default` w/ key from `TF_VAR_site2_mcp_key` |

### Tenant EUR — VRF-AFR-DEL.Services-V2 (Internal) — NDO-managed

Tenant content is no longer pushed by `apic-vmware/`. The `ndo/` root
creates schema `AFRICOM-V2` with a single template `Tenant_EUR_V2`; the
operator clicks **Deploy to sites** in the NDO UI to land it on Site1 and
Site2.

| ACI Object | NDO source | Description |
|------------|------------|-------------|
| Filter (cross-schema ref) | `data/nac-ndo/schema-africom-v2.nac.yaml` | `Any` filter is referenced from `AFRICOM / VRF_Template` (NDO requires unique object names per tenant) |
| Contract | `data/nac-ndo/schema-africom-v2.nac.yaml` | `Any_VRF-AFR-DEL.Services-V2` (scope: context, vzAny permit-all) |
| VRF | `data/nac-ndo/schema-africom-v2.nac.yaml` | `VRF-AFR-DEL.Services-V2` — vzAny provider + consumer of `Any_VRF-AFR-DEL.Services-V2` |
| Bridge Domains | `data/nac-ndo/schema-africom-v2.nac.yaml` | 36 BDs with descriptive names suffixed `-V2` (BD-AD-V2, BD-APP-SVR-V2, BD-CFG-MGMT-V2, etc.) — multi-subnet from legacy consolidation |
| EPGs | `data/nac-ndo/schema-africom-v2.nac.yaml` | 36 EPGs under `AppProf-NetCentric-V2` bound to `APCG-VDS1` on Site1 and `APCK-VDS1` on Site2 |
| Static port bindings | pushed by `scripts/deploy_bindings.py` after the NDO Deploy | per-EPG `staticPorts[]`; not modeled in nac-ndo YAML |
| ESG | `data/nac-aci-shared/tenant-eur-esgs.nac.yaml` (APIC-direct) | `ESG-All-Internal-V2` in `AppProf-AppCentric-V2`; selects all 36 EPGs in `AppProf-NetCentric-V2`. nac-ndo `~> 1.2.0` and Cisco mso provider `~> 1.7.x` do not model `endpoint_security_groups`, so the ESG layer rides the `nac-aci@0.7.0` wrapper instead. vzAny+permit-all on `VRF-AFR-DEL.Services-V2` keeps the ESG reachability-neutral. |

### Tenant EUR — VRF-DMZ-V2 — NDO-managed

| ACI Object | NDO source | Description |
|------------|------------|-------------|
| Contract | `data/nac-ndo/schema-africom-v2.nac.yaml` | `Any_VRF-DMZ-V2` (scope: context, vzAny permit-all) |
| VRF | `data/nac-ndo/schema-africom-v2.nac.yaml` | `VRF-DMZ-V2` — vzAny provider + consumer of `Any_VRF-DMZ-V2` |
| Bridge Domains | `data/nac-ndo/schema-africom-v2.nac.yaml` | 3 BDs: `BD-D64-PROXY-V2`, `BD-FWEB-PROXY-V2`, `BD-RWEB-PROXY-V2` |
| EPGs | `data/nac-ndo/schema-africom-v2.nac.yaml` | 3 EPGs under `AppProf-DMZ-V2` bound to `APCG-VDS1` on Site1 and `APCK-VDS1` on Site2 |
| Static port bindings | pushed by `scripts/deploy_bindings.py` after the NDO Deploy | per-EPG `staticPorts[]` |
| ESG | `data/nac-aci-shared/tenant-eur-esgs.nac.yaml` (APIC-direct) | `ESG-All-DMZ-V2` in `AppProf-AppCentric-V2`; selects all 3 EPGs in `AppProf-DMZ-V2`. Same `nac-aci@0.7.0` wrapper and reachability-neutrality story as `ESG-All-Internal-V2` above. |

---

## Repository layout

```
aci-redesign/
├── README.md                       directory README + production cutover runbook
├── DESIGN.md                       this file — design rationale + object inventory
│
├── apic-vmware/                    APIC-direct Terraform root (lab)
│   ├── main.tf                       4 module blocks: aci_site1, aci_mcp_site1,
│   │                                 aci_site2, aci_mcp_site2
│   ├── providers.tf                  default `aci` provider = Site1;
│   │                                 aliased `aci.site2` = Site2
│   ├── variables.tf                  per-fabric APIC + MCP variables
│   ├── lab.tfvars                    lab APIC IPs + manage_tenants=true (committed)
│   ├── prod.tfvars                   prod APIC IPs + manage_tenants=false (committed)
│   ├── terraform.tfvars.example      reference only — credentials via TF_VAR_* env vars
│   ├── Makefile                      plan/apply/auth-check/render/clean targets
│   │                                 (TFVARS_FILE=lab.tfvars default; override for prod)
│   ├── scripts/                      render-vmm-yaml, set-apic-password,
│   │                                 generate-mcp-key, auth-check, etc.
│   ├── templates/vmm-domain.nac.yaml.tftpl  rendered to ../data/nac-aci-<fabric>-rendered/
│   ├── README.md                     reference (env vars, error catalog)
│   └── README_LAB.md                 lab daily-driver
│
├── apic-vmware-prod/               APIC-direct Terraform root (prod; same vPC FI design as lab)
│   └── README.md                     prod-specific reference
│
├── ndo/                            NDO-managed Terraform root (tenant policy)
│   ├── main.tf                       calls netascode/nac-ndo/mso ~> 1.2.0
│   ├── providers.tf                  mso provider (platform=nd)
│   ├── variables.tf                  ndo_url/username/password/insecure/platform/domain
│   ├── terraform.tfvars              non-sensitive only; gitignored
│   ├── terraform.tfvars.example      copy + edit
│   ├── Makefile                      init/fmt/validate/plan/apply/destroy/auth-check/clean
│   ├── scripts/                      auth-check, set-ndo-password
│   ├── README.md                     NDO-specific runbook reference
│   └── README_LAB.md                 lab daily-driver
│
├── scripts/                        cross-cutting Python tools (run after NDO apply)
│   ├── dump_bindings.py              read AFRICOM/AppProf-AFR-PROD-V6, write JSON for AFRICOM-V2
│   ├── deploy_bindings.py            PATCH per-EPG staticPorts[] into AFRICOM-V2
│   ├── generate_fi_bindings.py       FI vPC static-binding generator (legacy; bare-metal only — EPGs are VMM-bound)
│   ├── check_fi_bindings_parity.py   CI guard for schema/manifest drift
│   ├── test_fi_bindings.py           unittest suite
│   ├── bindings.example.json         starter input
│   └── README.md                     CLI reference + JSON schema
│
└── data/
    ├── nac-aci-shared/               cross-fabric APIC-direct policy
    │   ├── modules.nac.yaml            disables wrapper's aci_mcp submodule
    │   └── README.md                   data tier note
    ├── nac-ndo/                      NDO-managed tenant policy (consumed by ndo/ root)
    │   ├── tenant.nac.yaml             stub: tenant EUR is referenced, not created
    │   └── schema-africom-v2.nac.yaml    schema AFRICOM-V2 with single template
    │                                   Tenant_EUR_V2 — 2 VRFs, 39 BDs, 2 ANPs,
    │                                   39 EPGs w/ VMM bindings, 2 vzAny contracts
    ├── nac-aci-site1/                Site1-only access/fabric policies
    │   └── access-policies.nac.yaml    VLAN pool 3501-3967, AAEP, leaf 101/102, VPC PG
    ├── nac-aci-site1-rendered/       gitignored; rebuilt every `make plan`
    │   └── vmm-domain.nac.yaml         VMware VMM with vCenter creds substituted in
    ├── nac-aci-site2/                Site2-only access/fabric policies
    │   └── access-policies.nac.yaml    same shape as Site1; leaf 119+191 (non-contiguous)
    ├── nac-aci-site2-rendered/       gitignored; rebuilt every `make plan`
    │   └── vmm-domain.nac.yaml         per-fabric VMM (same vCenter today)
    ├── nac-aci-{site1,site2}-prod/   production access/fabric policies (identical design to lab; vPC FI uplinks)
    ├── _archive/                     deprecated YAMLs (reference only)
    │   ├── tenant-epg-nac.nac.yaml.archived  old APIC-direct tenant model
    │   └── README.md                   archive note
    └── blueprints/                   reference NAC blueprints (design references)
```

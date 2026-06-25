# NDO-Terraform: Automated ACI Multi-Site IPv6 Deployment

## Presentation Reference Document

---

## 1. Project Overview

### What It Does

This project uses **Terraform** to automate the provisioning of Cisco ACI network infrastructure across two data center sites through **Nexus Dashboard Orchestrator (NDO)**. It manages the full lifecycle of Bridge Domains (BDs), End Point Groups (EPGs), VRFs, contracts, and site-level deployments for the **EUR tenant** under the **AFRICOM schema**.

### Why Automation

- **Consistency**: Identical configurations deployed to both sites (Site1 and Site2) from a single source of truth
- **Repeatability**: Every deployment is deterministic -- the same code produces the same result
- **Auditability**: All changes are tracked in Git with full commit history
- **Speed**: 35+ BDs and their associated EPGs, subnets, and site bindings deployed in minutes instead of hours of manual GUI work
- **Drift Prevention**: Terraform detects and corrects configuration drift from the desired state

### Scale

| Metric | Count |
|--------|-------|
| Bridge Domains | 35+ |
| EPGs | 35+ |
| IPv6 Subnets | 35+ |
| Site Deployments | 2 (Site1, Site2) |
| Terraform Resources | ~200+ |
| Lines of Terraform Code | ~4,200 (bds_epgs.tf) |

---

## 2. Architecture

### Components

```
┌──────────────────────────────────────────────────────────────┐
│                        GitLab CI/CD                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐   │
│  │ Validate  │───>│   Plan   │───>│       Deploy         │   │
│  │ (fmt chk) │    │(plan.tf) │    │ (plan + apply main)  │   │
│  └──────────┘    └──────────┘    └──────────────────────┘   │
│                                          │                   │
│                           State Backend: GitLab HTTP API     │
└──────────────────────────┬───────────────────────────────────┘
                           │ HTTPS
                           ▼
                 ┌───────────────────┐
                 │ Nexus Dashboard   │
                 │ Orchestrator (NDO)│
                 └─────────┬─────────┘
                      ┌────┴────┐
                      │         │
                 ┌────▼───┐ ┌──▼─────┐
                 │ Site1  │ │ Site2  │
                 │ (APIC) │ │ (APIC) │
                 └────────┘ └────────┘
```

### Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Infrastructure as Code | Terraform | Latest |
| NDO Provider | CiscoDevNet/mso | ~> 1.5.0 |
| ACI Provider | CiscoDevNet/aci | >= 2.0.0 |
| CI/CD Platform | GitLab CI/CD | On-premise |
| State Backend | GitLab HTTP State API | - |
| Runner | Shell executor on RHEL 8 | `aci-automation-runner` |
| Supplemental Tooling | Python 3 (binding generator) | - |

### NDO Object Hierarchy

```
NDO
└── Tenant: EUR
    └── Schema: AFRICOM
        ├── Template: UpgradeTemplate1 (VRF template)
        │   ├── VRF: AFR-PROD-V6 (vzAny enabled)
        │   ├── Contract: Any_AFR-PROD-V6 (scope: context, bidirectional)
        │   └── Filter: Any
        │
        ├── Template: L2_Stretched (majority of resources)
        │   ├── AppProf: AppProf-AFR-PROD-V6
        │   │   ├── EPG-NAC → BD-NAC (2609:efff:b33b:1500::1/64)
        │   │   ├── EPG-CFG-MGMT → BD-CFG-MGMT (2609:efff:b33b:6900::1/64)
        │   │   ├── EPG-DNS-MGMT → BD-DNS-MGMT (2609:efff:b33b:5300::1/64)
        │   │   ├── ... (30+ more EPG/BD pairs)
        │   │   └── EPG-GEF-MGMT → BD-GEF-MGMT (2609:efff:b33b:ef00::1/64)
        │   └── Site Deployments: Site1 + Site2
        │
        ├── Template: L2_Non-Stretched
        │   ├── EPG-DB-SVR → BD-DB-SVR
        │   └── EPG-SYSLOG → BD-SYSLOG
        │
        ├── Template: Site1-Specific_Only
        │   └── EPG-GEF-MGMT → BD-GEF-MGMT (Site1 only)
        │
        └── Template: Site2-Specific_Only
            └── EPG-BACKUP-SVR → BD-BACKUP-SVR (Site2 only)
```

---

## 3. How EPGs, BDs, and Services Were Determined

### The Starting Point: 216 VLAN-Named Bridge Domains

The existing EUR tenant in NDO had **216 Bridge Domains**, all named by VLAN number: `BD-V0005`, `BD-V0006`, `BD-V0009`, `BD-V0010`, `BD-V0015`, ... `BD-V2000`. Each BD had a matching `EPG-Vxxxx`. These were essentially a **1:1 VLAN-to-BD mapping** -- every VLAN on the fabric had its own BD and EPG, with no indication of what service the VLAN actually carried.

The 216 BDs were spread across 7 VRFs (EUR-E, EUR-AIS, EUR-AIV, EUR-AIZ, EUR-AIM, EUR-AIP, EUR-AOV) with IPv4 subnets like `136.215.132.1/24`. Many were pure L2 BDs (79 had no subnet at all), while others carried IPv4 gateway subnets.

The challenge: **VLAN numbers tell you nothing about what the service is.** `BD-V0015` could be DNS, NAC, or anything. The VLAN-based naming was inherited from the legacy network and carried forward into ACI without redesign.

### Step 1: Gather Source Data

Multiple data sources were collected to understand what each VLAN actually carried. These are preserved in the `backups/` directory:

**a) APIC BD/EPG Dumps (JSON exports from both APICs)**

- `schemas/Networking - Bridge Domains-Table-tn-EUR.json` -- Full dump of all 215 BDs from APIC with attributes (dn, name, unicast routing, flood settings)
- `schemas/bd_dump.json` -- Same BD inventory (215 BDs)
- `schemas/bd_epg_configs.json` -- BD configurations with flood/stretch/multicast settings for BDs like BD-V0479, BD-V0091, BD-V2150, etc.
- `schemas/africom_schema_full.json` (1.37 MB) -- Complete NDO schema export showing all templates, contracts, filters, ANPs, BDs, and VRFs

**b) APIC Endpoint Queries (live learned endpoints per EPG)**

A custom Python script (`APIC_ENDPOINT_QUERY_PACKAGE/get_epg_endpoints.json`) was run against **both APICs** to query every EPG for its learned endpoints:
- `apic_endpoints_155_155_32_20.json` -- 217 EPG records from APIC at Site G (Site1)
- `apic_endpoints_155_155_33_20.json` -- 216 EPG records from APIC at Site K (Site2)

Each record contains: EPG name, VLAN, endpoint count, port count, and a list of endpoints with MAC, IP, encap, and learning source. This data revealed **which VMs and physical endpoints were actually on each VLAN** -- for example, EPG-V0015 (VLAN 15) had NAC/ISE appliances, EPG-V0216 had DNS servers, etc.

**c) VM Deployment Data (vCenter export)**

- `IPv6_VMs.csv` -- 541 VM records exported from vCenter with custom fields including: VM name, POC email, role, service name, **IPv6 function code**, **IPv6 VLAN**, and **IPv6 subnet**. This was the primary source for confirming which service each VM belonged to and which IPv6 VLAN it should be assigned (e.g., ISE appliances → function 15, VLAN 3021, subnet 1500::/56; Cisco UC servers → function 40, VLAN 3064, subnet 4000::/56).

**d) NDO Schema Backups (snapshots before changes)**

Multiple schema backups were taken before any modifications:
- `schemas/schema_backup_*.json` (5 versions, ~1.3 MB each) -- Full NDO schema snapshots showing all templates, EPGs, BDs, and static port bindings. These provided the baseline for verifying port bindings and EPG-to-BD associations.

**e) APIC Configuration Backups**

- `backup_analysis/ScheduledBackup-20260203070000.tar.gz` (11 MB) -- Full APIC scheduled backup
- `backup_analysis/Backup-20260203144943.tar.gz` (10.9 MB) -- Manual APIC backup
- `backup_analysis/20250722070000.tar.gz` (5.3 MB) -- Older backup for comparison
- `backup_analysis/L3Outs-Table-tn-EUR.json` -- L3Out routing table for EUR tenant (9 L3Outs across 7 VRFs, including L3Out-RCC-E-G for AFR-PROD-V6)

**f) GitLab Network Functions List (wiki page)**

A GitLab wiki page titled "Network Functions List" defined the **standardized hex function codes** for every service type in the environment. This was the authoritative source for function code assignments:

| HEX | NAME | SUBNET | TYPE | DESCRIPTION |
|-----|------|--------|------|-------------|
| 00 | netman | 0000::/56 | infra1 | Network device related subnets |
| 01 | nms | 0100::/56 | infra1 | Network management services |
| 15 | nac | 1500::/56 | infra1 | Network Access Control |
| 40 | vvoip | 4000::/56 | inet1 | Voice/Video over IP |
| 53 | dns-mgmt | 5300::/56 | infra1 | DNS Management |
| ad | ad | ad00::/56 | infra1 | Active Directory |
| ... | ... | ... | ... | ... |

### Step 2: Cross-Reference to Identify Services per VLAN

With all the source data collected, each VLAN was identified through **cross-referencing**:

1. **APIC endpoint dumps** showed which MAC/IP addresses were learned on each `EPG-Vxxxx`, revealing the actual workloads (e.g., domain controllers on VLAN 3173, print servers on VLAN 3208)
2. **VM deployment CSV** (541 VMs) mapped each VM by name and role to its IPv6 function code and VLAN assignment
3. **NDO schema backups** confirmed existing EPG-to-BD associations, port bindings, and template placement
4. **Network Functions List** provided the standardized hex code for each service type

Not every VLAN had VM deployment data. The 26 VLANs confirmed from VM records are marked with a checkmark in the code. The remaining services were identified through APIC endpoint analysis and operational knowledge, and assigned VLANs from a confirmed-unused safe range (3050-3062).

### Step 3: Translate VLANs into Service-Named IPv6 EPGs

Once the VLAN-to-service mapping was established, each service was given a **descriptive name** and a **2-digit hex function code** (from the Network Functions List) to replace the opaque VLAN number. This was a deliberate redesign -- the IPv6 EPGs use meaningful names instead of carrying forward the VLAN-numbered convention.

The intermediate mapping artifacts were also preserved:
- `schemas/bd_epg_configs_v2.json` -- Side-by-side IPv4 BD configs vs IPv6 BD configs with subnet assignments
- `schemas/epg_port_bindings.json` -- 33 EPG records mapping each new IPv6 EPG to its VLAN, BD, and physical port bindings
- `bds_epgs.yaml` -- YAML inventory defining all 31+ EPGs with their VLAN, IPv6 subnet, function code, template, and verification status

The mapping from VLAN-numbered IPv4 EPGs to service-named IPv6 EPGs. Each `EPG-Vxxxx` is the original VLAN-based EPG whose port bindings and operational role informed the new IPv6 design:

| Original VLAN EPG | IPv6 EPGs Created | Identified Service |
|---------------------|-------------------|---------------------|
| EPG-V0015 (VLAN-based) | EPG-NAC, EPG-NMS | Infrastructure Management |
| EPG-V0021 | EPG-CFG-MGMT, EPG-SYSMAN | Configuration/Systems |
| EPG-V0033 | EPG-MECM, EPG-VHOST-MGMT, EPG-PATCH | Endpoint/Host Management |
| EPG-V0140 | EPG-ACAS-SCANNERS, EPG-ACAS-MGMT | Security Scanning (ACAS) |
| EPG-V0141 | EPG-C2C-SCANNERS | Security Scanning (C2C) |
| EPG-V0142 | EPG-OCSP | Certificate Validation |
| EPG-V0144 | EPG-PKI-SRV | Public Key Infrastructure |
| EPG-V0150 | EPG-AD | Active Directory |
| EPG-V0160 | EPG-VVOIP-MGMT, EPG-ADFS | Voice/Federation |
| EPG-V0161 | EPG-VVOIP-PROXY | Voice Proxy |
| EPG-V0163 | EPG-LMR | Land Mobile Radio |
| EPG-V0178 | EPG-E911-SVR | Emergency Services |
| EPG-V0210 | EPG-LB | Load Balancing |
| EPG-V0216 | EPG-DNS-MGMT | DNS Management |
| EPG-V0218 | EPG-AFRICOM-DNS | RCC DNS Services |
| EPG-V0219 | EPG-DHCP-SVR | DHCP Services |
| EPG-V0220 | EPG-SMTP-SVR | SMTP/Email |
| EPG-V0260 | EPG-D64-PROXY, EPG-GEF-MGMT | Proxy/GEF Services |
| EPG-V0261 | EPG-RWEB-PROXY | Reverse Web Proxy |
| EPG-V0262 | EPG-FWEB-PROXY | Forward Web Proxy |
| EPG-V0420 | EPG-APP-SVR, EPG-WEB-SVR | Application/Web Hosting |
| EPG-V0450 | EPG-FMWR-SVR | Firmware Distribution |
| EPG-V0470 | EPG-AFRICOM-SVR | RCC Server |
| EPG-V0471 | EPG-AFRICOM-DCO, EPG-ADM-DCO | RCC/Admin Operations |
| EPG-V0472 | EPG-AFRICOM-UNIX | RCC UNIX Services |
| EPG-V0520 | EPG-PRINT-SVR | Print Services |
| EPG-V0521 | EPG-FILE-SVR | File Services |
| EPG-V0522 | EPG-BACKUP-SVR | Backup Services |
| EPG-V0570 | EPG-DB-SVR | Database Services |
| EPG-V0572 | EPG-SYSLOG | System Logging |

### Step 3: VLAN Assignment for IPv6 EPGs

The IPv6 EPGs needed their own VLAN IDs for the fabric encapsulation (the VLAN used in the static port bindings). These are **new VLANs in the 3000+ range**, separate from the original IPv4 VLANs. The assignment came from two sources:

- **VM deployment data** (26 VLANs confirmed, marked with a checkmark in the code): The production VM deployment records showed which 3000-range VLANs were already allocated or planned for each service. Examples: VLAN 3021 for NAC, VLAN 3083 for DNS-MGMT, VLAN 3173 for Active Directory.
- **Safe range allocation** (remaining services, marked with a warning icon): Services without existing VM deployment data were assigned VLANs from a **verified-unused range** (3050-3062). These include LB, RCC-SVR, RCC-DNS, RCC-DCO, RCC-UNIX, PKI-SRV, LMR, D64-PROXY, RWEB-PROXY, FWEB-PROXY, FMWR-SVR, E911-SVR, and GEF-MGMT.

The key distinction: the original IPv4 BDs (`BD-V0015`, etc.) used VLANs in a different range for their IPv4 encapsulation. The IPv6 EPGs use **separate VLANs in the 3000+ range** so both IPv4 and IPv6 services can coexist on the same physical infrastructure without conflict.

### Step 4: IPv6 Address Derivation

The IPv6 addressing scheme was designed with a consistent, predictable formula:

```
Base prefix:     2609:efff:b33b
Function code:   [2-digit hex] (unique per service)
Subnet:          2609:efff:b33b:[function_code]00::/64
Gateway:         2609:efff:b33b:[function_code]00::1/64
```

Each service function's hex code was chosen to be memorable or meaningful where possible:

| Function Code | Service | Mnemonic |
|---------------|---------|----------|
| 01 | NMS | Network Management = first function |
| 15 | NAC | Network Access Control |
| 53 | DNS-MGMT | Port 53 = DNS |
| ad | AD | Active Directory |
| af | ADFS | AD Federation Services |
| db | DB-SVR | Database |
| d9 | SYSLOG | Syslog (d9 = log) |
| e9 | E911-SVR | E911 = emergency |
| ec | MECM | Endpoint Configuration Manager |

### Step 5: Template Placement Decisions

Each BD/EPG was assigned to one of four NDO templates based on its site deployment requirements:

| Template | Criteria | EPG Count |
|----------|----------|-----------|
| **L2_Stretched** | Service runs at BOTH sites with L2 extension between them | ~30 (majority) |
| **L2_Non-Stretched** | Service runs at both sites but each site is independent (no L2 stretch) | 2 (DB-SVR, SYSLOG) |
| **Site1-Specific_Only** | Service runs ONLY at site Site1 | 1 (GEF-MGMT) |
| **Site2-Specific_Only** | Service runs ONLY at site Site2 | 1 (BACKUP-SVR) |

The template decisions were based on operational requirements:
- **Databases and logs** (DB-SVR, SYSLOG) are site-local for data sovereignty and latency -- no L2 stretch needed
- **Backup** is K-site only because the backup infrastructure resides at Site2
- **GEF management** is G-site only because the GEF equipment is at Site1
- **Everything else** is L2-stretched for high availability across both sites

### Step 6: Port Binding Inheritance from VLAN EPGs

The critical link between old and new: each IPv6 EPG needs to be deployed on the **same physical switch ports** as the IPv4 VLAN EPG it replaces. The Python binding generator script (`generate_ipv6_bindings3.py`) automates this by:

1. **Query NDO** for all existing static port bindings on every `EPG-Vxxxx` (the VLAN-named IPv4 EPGs)
2. **Match** each new IPv6 EPG to its source VLAN EPG (e.g., EPG-NAC gets its ports from EPG-V0015, because V0015 is the VLAN that carries NAC traffic)
3. **Clone** the port bindings (VPC paths, leaf pairs, deployment immediacy) from the VLAN EPG, substituting the new IPv6 VLAN encapsulation
4. **Filter** by site/template (G-Specific only gets Site1 ports, K-Specific only gets Site2 ports)
5. **Default** to standard VPC paths on leaves 101/102 if a reference VLAN EPG had no existing bindings

This inheritance approach means the IPv6 services land on exactly the same physical leaf ports and server connections as their IPv4 predecessors -- the same racks, same VPCs, same hosts -- just with IPv6 addressing and new VLAN encapsulation.

The generated binding files are preserved in `backups/ipv6-bindings/` with timestamps (7 versions from Jan 21-28, 2026), each containing `reference_epg` fields that document the exact IPv4-to-IPv6 EPG lineage.

A cleanup script (`backups/remove_all_rcc_bindings.json`) was also created to remove IPv6 bindings (VLANs 3001-3500) from specific leaves when re-deployment was needed.

### Step 7: Domain Binding Decisions

Two types of EPG domain bindings were applied:

- **PhysDom_ACI_IPv6** (Physical Domain): Applied to ALL EPGs at both sites -- required for bare-metal and physical server connectivity
- **VMware VMM Domain** (variable `vmm_domain_name`): Applied only to **EPG-NAC at Site2** -- the only service that required VMware virtual machine connectivity at the K site

### Consolidated EUR Tenant (Future)

A separate configuration (`eur_consolidated.tf.disabled`) was designed to consolidate the original 216 IPv4 BDs into 7 VRF-based logical groups under a new `EUR-Consolidated` tenant with templates organized by VRF (EUR-E, EUR-AIS, EUR-AIV, EUR-AIZ, EUR-AIM, EUR-AIP, EUR-AOV). This consolidation effort is paused and preserved for future implementation.

---

## 4. IPv6 Address Design

All subnets follow a consistent addressing scheme:

```
2609:efff:b33b:[function_code]00::1/64
```

Where `[function_code]` is a 2-digit hex value unique to each service function.

### Complete IPv6 and VLAN Reference Map

| Func | BD Name | IPv6 Gateway | VLAN | Template | Category |
|------|---------|-------------|------|----------|----------|
| 01 | BD-NMS | 2609:efff:b33b:0100::1/64 | 3001 | L2_Stretched | Infrastructure |
| 15 | BD-NAC | 2609:efff:b33b:1500::1/64 | 3021 | L2_Stretched | Infrastructure |
| 1b | BD-LB | 2609:efff:b33b:1b00::1/64 | 3050 | L2_Stretched | Network Services |
| 40 | BD-VVOIP-MGMT | 2609:efff:b33b:4000::1/64 | 3064 | L2_Stretched | Voice/Comms |
| 41 | BD-VVOIP-PROXY | 2609:efff:b33b:4100::1/64 | 3065 | L2_Stretched | Voice/Comms |
| 53 | BD-DNS-MGMT | 2609:efff:b33b:5300::1/64 | 3083 | L2_Stretched | Network Services |
| 66 | BD-VHOST-MGMT | 2609:efff:b33b:6600::1/64 | 3102 | L2_Stretched | Infrastructure |
| 69 | BD-CFG-MGMT | 2609:efff:b33b:6900::1/64 | 3105 | L2_Stretched | Infrastructure |
| a3 | BD-ADM-DCO | 2609:efff:b33b:a300::1/64 | 3163 | L2_Stretched | RCC Services |
| ad | BD-AD | 2609:efff:b33b:ad00::1/64 | 3173 | L2_Stretched | Directory/Auth |
| af | BD-ADFS | 2609:efff:b33b:af00::1/64 | 3175 | L2_Stretched | Directory/Auth |
| bc | BD-AFRICOM-SVR | 2609:efff:b33b:bc00::1/64 | 3051 | L2_Stretched | RCC Services |
| bd | BD-AFRICOM-DNS | 2609:efff:b33b:bd00::1/64 | 3052 | L2_Stretched | RCC Services |
| be | BD-AFRICOM-DCO | 2609:efff:b33b:be00::1/64 | 3053 | L2_Stretched | RCC Services |
| bf | BD-AFRICOM-UNIX | 2609:efff:b33b:bf00::1/64 | 3054 | L2_Stretched | RCC Services |
| c0 | BD-ACAS-SCANNERS | 2609:efff:b33b:c000::1/64 | 3192 | L2_Stretched | Security |
| c1 | BD-C2C-SCANNERS | 2609:efff:b33b:c001::1/64 | 3442 | L2_Stretched | Security |
| c3 | BD-SYSMAN | 2609:efff:b33b:c300::1/64 | 3195 | L2_Stretched | Infrastructure |
| c5 | BD-OCSP | 2609:efff:b33b:c500::1/64 | 3197 | L2_Stretched | Security |
| c6 | BD-ACAS-MGMT | 2609:efff:b33b:c600::1/64 | 3198 | L2_Stretched | Security |
| ca | BD-PKI-SRV | 2609:efff:b33b:ca00::1/64 | 3055 | L2_Stretched | Security |
| cb | BD-LMR | 2609:efff:b33b:cb00::1/64 | 3056 | L2_Stretched | Voice/Comms |
| d0 | BD-PRINT-SVR | 2609:efff:b33b:d000::1/64 | 3208 | L2_Stretched | Storage |
| d1 | BD-FILE-SVR | 2609:efff:b33b:d100::1/64 | 3209 | L2_Stretched | Storage |
| d2 | BD-DHCP-SVR | 2609:efff:b33b:d200::1/64 | 3210 | L2_Stretched | Network Services |
| d5 | BD-SMTP-SVR | 2609:efff:b33b:d500::1/64 | 3213 | L2_Stretched | Network Services |
| d6 | BD-D64-PROXY | 2609:efff:b33b:d600::1/64 | 3057 | L2_Stretched | Proxy Services |
| d7 | BD-RWEB-PROXY | 2609:efff:b33b:d700::1/64 | 3058 | L2_Stretched | Proxy (Public) |
| d8 | BD-FWEB-PROXY | 2609:efff:b33b:d800::1/64 | 3059 | L2_Stretched | Proxy (Public) |
| d9 | BD-SYSLOG | 2609:efff:b33b:d900::1/64 | 3217 | L2_Non-Stretched | Database/Logging |
| db | BD-DB-SVR | 2609:efff:b33b:db00::1/64 | 3219 | L2_Non-Stretched | Database/Logging |
| dd | BD-BACKUP-SVR | 2609:efff:b33b:dd00::1/64 | 3221 | Site2-Specific_Only | Storage |
| e0 | BD-APP-SVR | 2609:efff:b33b:e000::1/64 | 3224 | L2_Stretched | App/Web |
| e3 | BD-FMWR-SVR | 2609:efff:b33b:e300::1/64 | 3060 | L2_Stretched | App/Web |
| e4 | BD-WEB-SVR | 2609:efff:b33b:e400::1/64 | 3228 | L2_Stretched | App/Web (Public) |
| e6 | BD-PATCH | 2609:efff:b33b:e600::1/64 | 3230 | L2_Stretched | Infrastructure |
| e9 | BD-E911-SVR | 2609:efff:b33b:e900::1/64 | 3061 | L2_Stretched | Voice/Comms |
| ec | BD-MECM | 2609:efff:b33b:ec00::1/64 | 3236 | L2_Stretched | Infrastructure |
| ef | BD-GEF-MGMT | 2609:efff:b33b:ef00::1/64 | 3062 | Site1-Specific_Only | Infrastructure |

**Public-facing services**: BD-RWEB-PROXY, BD-FWEB-PROXY, BD-WEB-SVR

---

## 5. Terraform Resource Structure

### Per Bridge Domain Pattern

Every BD follows the same three-resource pattern in Terraform:

```
┌─────────────────────────┐
│  mso_schema_template_bd │  BD definition (L2 settings, VRF association)
└────────────┬────────────┘
             │
┌────────────▼────────────────────┐
│  mso_schema_template_bd_subnet  │  IPv6 gateway subnet (/64)
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│  mso_schema_template_anp_epg    │  EPG in AppProf-AFR-PROD-V6
└─────────────────────────────────┘
```

### Site-Level Resources

After template-level definitions, each BD/EPG is deployed to sites:

```
┌───────────────────────────┐     ┌───────────────────────────┐
│  mso_schema_site_bd       │     │  mso_schema_site_anp_epg  │
│  (Site1)                  │     │  (Site1)                  │
└───────────────────────────┘     └─────────────┬─────────────┘
                                                │
┌───────────────────────────┐     ┌─────────────▼─────────────────────┐
│  mso_schema_site_bd       │     │  mso_schema_site_anp_epg_domain   │
│  (Site2)                  │     │  (PhysDom_ACI_IPv6 + VMM domain)  │
└───────────────────────────┘     └───────────────────────────────────┘
```

### Bridge Domain Configuration (Standard Settings)

All BDs share these settings for L2 stretched multi-site operation:

| Setting | Value | Purpose |
|---------|-------|---------|
| layer2_unknown_unicast | proxy | Spine-proxy for unknown unicast (multi-site) |
| layer2_stretch | true | Stretch BD across both sites |
| unicast_routing | true | Enable IPv6 routing |
| intersite_bum_traffic | true | Allow BUM traffic between sites |
| optimize_wan_bandwidth | true | Reduce inter-site WAN traffic |
| arp_flooding | true | Flood ARP within the BD |
| unknown_multicast_flooding | flood | Flood unknown multicast |
| ipv6_unknown_multicast_flooding | flood | Flood unknown IPv6 multicast |

### VRF and Contract Configuration

```
AFR-PROD-V6
├── vzAny: enabled
├── Contract: Any_AFR-PROD-V6
│   ├── Scope: context (VRF-wide)
│   ├── Filter: Any (bidirectional)
│   ├── vzAny Provider
│   └── vzAny Consumer
└── All BDs associated to this VRF
```

The vzAny contract with an "Any" filter enables full inter-EPG communication within the VRF -- all EPGs under AFR-PROD-V6 can communicate with each other without individual contract definitions.

---

## 6. GitLab CI/CD Pipeline

### Pipeline Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────────┐
│  VALIDATE   │────>│    PLAN     │────>│      DEPLOY         │
│             │     │             │     │                     │
│ terraform   │     │ terraform   │     │ terraform init      │
│ fmt -check  │     │ init        │     │ terraform plan      │
│             │     │ terraform   │     │ terraform apply     │
│ (may fail)  │     │ plan        │     │                     │
│             │     │ terraform   │     │ (main branch only)  │
│             │     │ show > txt  │     │                     │
└─────────────┘     └─────────────┘     └─────────────────────┘
                    Triggers on:         Triggers on:
                    - merge requests     - main branch
                    - main branch

                    ┌─────────────────────┐
                    │     DESTROY         │
                    │                     │
                    │ terraform init      │
                    │ terraform plan      │
                    │   -destroy          │
                    │ terraform apply     │
                    │                     │
                    │ (manual trigger)    │
                    └─────────────────────┘
```

### Stage Details

#### Stage 1: Validate

- Runs `terraform fmt -check` to enforce code formatting
- `allow_failure: true` -- formatting issues do not block the pipeline

#### Stage 2: Plan

- Initializes Terraform with the GitLab HTTP state backend
- Runs `terraform plan -out=plan.tfplan -parallelism=3 -refresh=false`
- Generates a human-readable `plan.txt` from the plan file
- Saves `plan.tfplan` and `plan.txt` as pipeline artifacts for review
- Runs on both merge requests (for review) and the main branch
- Retry: up to 2 attempts on failure (NDO API intermittent errors)

#### Stage 3: Deploy

- Initializes Terraform with the GitLab HTTP state backend
- Runs its own `terraform plan` + `terraform apply` in a single job
- This ensures the plan is always created against the current state (prevents "stale plan" errors)
- Runs only on the main branch (after merge)
- Retry: up to 2 attempts on failure

#### Stage 4: Destroy (Manual)

- Triggered manually from the GitLab UI
- Runs `terraform plan -destroy` followed by `terraform apply`
- Used only for tearing down the full environment

### State Management

```
┌──────────────────┐         ┌────────────────────────────────┐
│ Command-Line     │         │ GitLab Pipeline                │
│ (SSH to server)  │         │ (CI/CD Runner)                 │
│                  │         │                                │
│ terraform init   │         │ terraform init                 │
│   -backend-      │─────────│   -backend-config=...          │
│    config=...    │  SHARED │                                │
│                  │  STATE  │                                │
└──────────────────┘         └────────────────────────────────┘
         │                            │
         └──────────┬─────────────────┘
                    ▼
        ┌───────────────────────┐
        │ GitLab HTTP State API │
        │                       │
        │ State locking (POST)  │
        │ State unlock (DELETE) │
        │                       │
        │ Auth: Personal Access │
        │ Token (TF_STATE_TOKEN)│
        └───────────────────────┘
```

- **Backend**: GitLab HTTP API (`backend "http" {}`)
- **Authentication**: Personal Access Token with `api` scope (not `CI_JOB_TOKEN` -- insufficient permissions for state locking)
- **Locking**: POST/DELETE on the lock endpoint prevents concurrent modifications
- **Shared**: Both pipeline and CLI operations use the same remote state
- **Initial migration**: Local state was migrated once using `terraform init -migrate-state`

### CI/CD Variables (GitLab Settings > CI/CD > Variables)

| Variable | Purpose | Protected | Masked |
|----------|---------|-----------|--------|
| `TF_VAR_ndo_username` | NDO login username | Yes | No |
| `TF_VAR_ndo_password` | NDO login password | Yes | Yes |
| `TF_VAR_ndo_url` | NDO URL (https://...) | Yes | No |
| `TF_VAR_apic_username` | APIC username | Yes | No |
| `TF_VAR_apic_password` | APIC password | Yes | Yes |
| `TF_VAR_apic_g_url` | Site G APIC URL | Yes | No |
| `TF_VAR_apic_k_url` | Site K APIC URL | Yes | No |
| `TF_STATE_TOKEN` | GitLab PAT for state backend | Yes | Yes |

All use the `TF_VAR_` prefix so Terraform reads them directly as environment variables -- no shell `export` commands needed. This avoids a known issue where double-quote expansion in shell scripts mangles passwords containing special characters.

### Pipeline Variable

```yaml
variables:
  TF_VAR_vrf_template_name: "UpgradeTemplate1"
```

This sets the VRF template name for production deployments.

### Runner

- **Type**: Shell executor (not Docker)
- **Host**: `apckw059aau0096` (RHEL 8)
- **Name**: `aci-automation-runner`
- **Installation**: User-level (`~/gitlab-runner/gitlab-runner run`)
- **No systemd**: Must be manually restarted after server reboots

---

## 7. Lab vs Production

The codebase supports both environments using a single set of `.tf` files with variable-driven differences.

| Setting | Lab | Production |
|---------|-----|------------|
| VRF Template Name | `VRF_Template` | `UpgradeTemplate1` |
| MSO Provider `domain` | `"local"` | `null` (omitted) |
| MSO Provider `platform` | `"nd"` | `null` (omitted) |
| NDO URL | Lab NDO | Production NDO |
| Credentials | lab.tfvars | GitLab CI/CD variables |
| State Backend | Local file | GitLab HTTP API |

### Running Lab

```bash
terraform init
terraform plan -var-file="lab.tfvars" -parallelism=3 -out=plan.tfplan
terraform apply "plan.tfplan"
```

### Running Production (CLI)

```bash
terraform init -backend-config="address=..." -backend-config="..."
nohup terraform plan -var-file="prod.tfvars" -parallelism=3 -refresh=false \
  -out=plan.tfplan > plan_output.log 2>&1 &
tail -f plan_output.log
```

### Running Production (Pipeline)

Push to `main` branch -- the pipeline handles everything automatically.

---

## 8. NDO API Challenges and Mitigations

### The Problem

With 200+ resources, a full `terraform plan` triggers hundreds of API calls to NDO for state refresh. The NDO API cannot handle this volume reliably:

| Error | Cause |
|-------|-------|
| "Invalid username or password" | NDO session token expires mid-refresh |
| "plugin did not respond" | Terraform provider crashes waiting for NDO |
| "request cancelled: grpcprovider" | Provider times out during UpgradeResourceState |

### Mitigations

| Strategy | How | When |
|----------|-----|------|
| `-refresh=false` | Skip state refresh entirely | Every plan/apply in pipeline |
| `-parallelism=3` | Limit concurrent API calls (max safe value) | Every plan/apply |
| `nohup` + background | Survive SSH disconnects on long runs | Manual CLI operations |
| `-target=` | Limit scope to specific resources | Single-resource changes |
| `retry: max: 2` | Auto-retry on intermittent failures | Pipeline jobs |
| Periodic full refresh | Verify state matches NDO during off-hours | Manual, as needed |

### Known Provider Bug

**BD-NMS subnet** (`2609:efff:b33b:0100::1/64`): The `0100` hex group has a leading zero. NDO normalizes the address differently than the MSO provider expects on read-back. The provider creates the subnet but cannot match it when reading, causing:

```
Error: Provider produced inconsistent result after apply
root object was present, but now absent
```

**Workaround**: The `bd_nms_subnet` resource is commented out in Terraform. The subnet is managed manually in NDO.

---

## 9. Supplemental Tooling

### IPv6 Binding Generator (Python)

`generate_ipv6_bindings3.py` -- A Python script that automates static port binding deployment to NDO via direct API calls.

**Purpose**: Deploy IPv6 VLAN port bindings to EPGs that Terraform cannot manage efficiently (static port bindings at scale).

**Features**:
- Schema backup before deployment
- Environment variable or interactive credential input
- Dry-run mode for testing
- Auto-discovers RCC EPGs from the AFRICOM schema
- Clones port bindings from existing IPv4 reference EPGs
- Deploys in batches of 50 patches to NDO API
- Supports leaves 101/102 (111/112 deferred)
- VLAN conflict detection

**Modes**:

```bash
python3 generate_ipv6_bindings3.py dry-run    # Preview only
python3 generate_ipv6_bindings3.py deploy     # Deploy to NDO
python3 generate_ipv6_bindings3.py both       # Generate + deploy
```

---

## 10. File Structure

```
ndo-terraform/
├── main.tf                         # Backend (HTTP), providers (MSO, ACI)
├── variables.tf                    # Input variables (NDO creds, template name)
├── bds_epgs.tf                     # Main config: 35+ BDs, EPGs, subnets, site
│                                   #   deployments, domain bindings (~4,200 lines)
├── snake.tf                        # Alternate config (hardcoded UpgradeTemplate1)
├── .gitlab-ci.yml                  # CI/CD pipeline (validate, plan, deploy, destroy)
├── .gitignore                      # Excludes state, tfvars, creds, generated files
├── PIPELINE_SETUP.md               # Full CI/CD and operational documentation
├── prod.tfvars                     # Production variable values (gitignored)
├── lab.tfvars                      # Lab variable values (gitignored)
├── terraform.tfvars                # Default tfvars for local dev (gitignored)
├── generate_ipv6_bindings3.py      # Python: NDO IPv6 port binding automation
├── vault.yml                       # Ansible Vault encrypted credentials
├── vault_pass.txt                  # Vault password (gitignored)
├── .terraform.lock.hcl             # Provider version lock
│
├── *.tf.disabled                   # Disabled configs (EUR consolidated, L3Outs,
│                                   #   VHOST-MGMT) -- preserved for reference
│
├── test-ndo/                       # Minimal test configuration
│   ├── test.tf                     #   Basic MSO site connectivity test
│   └── terraform.tfvars            #   Test credentials
│
└── tf-modules/nac-ndo/             # Cisco Network-as-Code NDO module
    ├── main.tf                     #   Locals, NDO version data
    ├── variables.tf                #   Module input variables
    ├── outputs.tf                  #   Module outputs
    ├── versions.tf                 #   Provider/Terraform version constraints
    ├── merge.tf                    #   YAML merge and model loading
    ├── ndo_schemas.tf              #   Schema/template resources
    ├── ndo_sites.tf                #   Site resources
    ├── ndo_system.tf               #   System configuration
    ├── ndo_tenants.tf              #   Tenant resources
    ├── ndo_site_connectivity.tf    #   Site connectivity
    ├── ndo_deploy_templates.tf     #   Template deployment
    ├── defaults/defaults.yaml      #   Default NDO settings
    ├── README.md                   #   Module documentation
    └── examples/                   #   Usage examples (YAML, HCL)
```

---

## 11. Operational Procedures

### Standard Workflow: Making a Change

1. **Edit** `.tf` files locally (e.g., add a new BD/EPG)
2. **Commit** and push to a feature branch
3. **Open Merge Request** in GitLab
4. **Pipeline runs**: validate + plan stages execute automatically
5. **Review** the `plan.txt` artifact to verify planned changes
6. **Merge** to `main` branch
7. **Pipeline runs**: deploy stage executes `plan` + `apply` on main

### Manual Command-Line Workflow

```bash
# SSH to runner host
ssh apckw059aau0096

# Initialize backend
terraform init -backend-config="address=..." ...

# Plan (background for long runs)
nohup terraform plan -parallelism=3 -refresh=false \
  -out=plan.tfplan > plan_output.log 2>&1 &
tail -f plan_output.log

# Apply
nohup terraform apply -parallelism=3 "plan.tfplan" \
  > apply_output.log 2>&1 &
tail -f apply_output.log
```

### Targeted Operations

For single-resource changes:

```bash
nohup terraform apply -parallelism=1 -auto-approve -refresh=false \
  -target=mso_schema_template_bd_subnet.bd_example_subnet \
  > apply_output.log 2>&1 &
```

### Recovering from State Lock

```bash
terraform force-unlock <LOCK_ID>
```

### Runner Restart (after server reboot)

```bash
ssh apckw059aau0096
pkill gitlab-runner
nohup ~/gitlab-runner/gitlab-runner run &
```

---

## 12. Security and Credentials

### Credential Handling

| Credential | Storage | Access |
|------------|---------|--------|
| NDO username/password | GitLab CI/CD variables (masked) | Pipeline via `TF_VAR_` env vars |
| APIC credentials | GitLab CI/CD variables (masked) | Pipeline via `TF_VAR_` env vars |
| State backend token | GitLab CI/CD variables (masked) | Pipeline via `TF_STATE_TOKEN` |
| Lab credentials | `lab.tfvars` (gitignored) | Local dev only |

### What Is Excluded from Git

- All `.tfvars` files (credentials)
- Terraform state files (`*.tfstate`)
- Plan files (`*.tfplan`)
- Vault password (`vault_pass.txt`)
- Generated JSON data files
- Any file matching `*password*`, `*secret*`, `*token*`, `*credential*`

---

## 13. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `TF_VAR_` prefix on CI variables | Terraform reads them directly; avoids shell `export` that mangled special characters in passwords |
| Personal Access Token for state | `CI_JOB_TOKEN` lacked state locking permissions on this GitLab instance |
| `-parallelism=3` | Highest safe value for NDO API; higher causes session timeouts |
| `-refresh=false` in pipeline plan | Prevents NDO API overload with 200+ resources; drift detected manually |
| Plan + Apply in same deploy job | Prevents "stale plan" errors caused by state changes between separate CI jobs |
| `retry: max: 2` | NDO auth errors are intermittent; auto-retry usually succeeds |
| Single long `terraform init` lines | Avoids YAML multiline syntax that broke on the remote GitLab |
| `nohup` for manual SSH runs | Prevents SSH timeouts from killing long-running operations |
| BD-NMS subnet commented out | MSO provider bug with IPv6 leading-zero hex groups |
| Lab/prod via `.tfvars` | Single codebase with env-specific values; avoids maintaining two copies |

---

## 14. Future Improvements

1. **Split into smaller state files**: Break `bds_epgs.tf` into separate modules/workspaces (per site, per function group) to enable full state refresh
2. **Remove `-refresh=false`**: Once state is split, each refresh covers fewer resources and completes reliably
3. **Upgrade MSO provider**: Later versions may handle API sessions better and fix the BD-NMS IPv6 bug
4. **Leaves 111/112 port bindings**: Extend the Python binding generator for the second leaf pair
5. **L3Out automation**: Re-enable disabled L3Out configurations when NDO provider support improves

---

## Appendix A: Template Distribution

| Template | Site(s) | EPG Count | Description |
|----------|---------|-----------|-------------|
| L2_Stretched | Site1 + Site2 | ~30 | Majority of services; L2 stretched across both sites |
| L2_Non-Stretched | Site1 + Site2 | 2 | DB-SVR, SYSLOG; not L2 stretched |
| Site1-Specific_Only | Site1 only | 1 | GEF-MGMT; Site G specific |
| Site2-Specific_Only | Site2 only | 1 | BACKUP-SVR; Site K specific |

## Appendix B: Service Categories

| Category | EPGs | Description |
|----------|------|-------------|
| Infrastructure Management | NAC, CFG-MGMT, MECM, NMS, VHOST-MGMT, SYSMAN, PATCH | Core infrastructure services |
| Network Services | LB, DNS-MGMT, RCC-DNS, DHCP-SVR, SMTP-SVR | Network and connectivity |
| Voice/Communications | VVOIP-MGMT, VVOIP-PROXY, LMR, E911-SVR | Voice and emergency services |
| Security | ACAS-SCANNERS, C2C-SCANNERS, OCSP, PKI-SRV, ACAS-MGMT | Security scanning and PKI |
| Directory/Auth | AD, ADFS | Active Directory and federation |
| Proxy Services | D64-PROXY, RWEB-PROXY (public), FWEB-PROXY (public) | Forward/reverse proxy |
| Application/Web | APP-SVR, WEB-SVR (public), FMWR-SVR | Application hosting |
| RCC Services | RCC-SVR, RCC-DCO, RCC-UNIX, ADM-DCO | RCC operations |
| Storage | PRINT-SVR, FILE-SVR, BACKUP-SVR | File and backup services |
| Database/Logging | DB-SVR, SYSLOG | Data and log management |

## Appendix C: Domain Bindings

| Domain Type | Name | Applies To |
|-------------|------|-----------|
| Physical | PhysDom_ACI_IPv6 | All EPGs at both sites |
| VMware VMM | (var.vmm_domain_name) | EPG-NAC at Site2 site |

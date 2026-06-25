# RCC-E IPv6 Infrastructure Deployment
## Executive Summary

**Date:** January 23, 2026  
**Project:** Regional Cyber Center Europe (RCC-E) IPv6 Network Infrastructure  
**Environment:** Cisco ACI Multi-Site (NDO) - Sites Site1 & Site2

---

## 1. Overview

This deployment creates the IPv6 network infrastructure for RCC-E using Cisco Nexus Dashboard Orchestrator (NDO) and Application Centric Infrastructure (ACI). The solution consists of two integrated components:

| Component | Purpose |
|-----------|---------|
| **Terraform Configuration** (`bds_epgs.tf`) | Creates IPv6 network objects (Bridge Domains, EPGs, Subnets) in NDO |
| **Python Script** (`generate_ipv6_bindings3.py`) | Configures physical port bindings for the new IPv6 EPGs |

---

## 2. Terraform Configuration Summary

### What It Creates

The Terraform plan provisions **39 IPv6 Endpoint Groups (EPGs)** organized across **10 consolidated Bridge Domains**:

| Template | Scope | EPG Count | Sites |
|----------|-------|-----------|-------|
| L2_Stretched | Stretched across both sites | 29 | Site1, Site2 |
| Site1-Specific_Only | Site-local | 1 | Site1 only |
| Site2-Specific_Only | Site-local | 1 | Site2 only |
| L2_Non-Stretched | Both sites (non-stretched) | 2 | Site1, Site2 |

### Bridge Domains Created

| BD Name | Purpose | IPv6 Subnets |
|---------|---------|--------------|
| BD-INFRA-MGMT | Infrastructure Management | NAC, CFG-MGMT, MECM, LB |
| BD-NETWORK-SERVICES | Network Services | DNS-MGMT, RCC-DNS, DHCP-SVR, SMTP-SVR |
| BD-VOICE-VIDEO | Voice/Video Communications | VVOIP-MGMT, VVOIP-PROXY, LMR, E911-SVR |
| BD-SECURITY | Security & Compliance | ACAS-SCANNERS, C2C-SCANNERS, OCSP, PKI-SRV |
| BD-IDENTITY | Identity & Authentication | AD, ADFS |
| BD-PROXY | Proxy Services | D64-PROXY, RWEB-PROXY, FWEB-PROXY |
| BD-APPLICATION | Application Servers | APP-SVR, WEB-SVR, FMWR-SVR |
| BD-DATA | Data Services | DB-SVR, PRINT-SVR, FILE-SVR, SYSLOG |
| BD-AFRICOM-CORE | RCC Core Services | RCC-SVR, RCC-DCO, RCC-UNIX |
| BD-SITE-SPECIFIC | Site-Local Services | GEF-MGMT (G), BACKUP-SVR (K) |

### IPv6 Addressing Scheme

- **Format:** `[function_code]00::1/56`
- **Example:** Function `d0` (Print Server) → `d000::1/56`
- **Total Subnets:** 43 IPv6 subnets provisioned

### Key Configuration Details

- **VRF:** AFR-PROD-V6 (existing)
- **Contract:** Any_AFR-PROD-V6 (vzAny enabled)
- **Physical Domain:** PhysDom_ACI_Nexus
- **L3Out Association:** L3Out-RCC-E (for external routing)

---

## 3. Python Script Summary

### Purpose

The `generate_ipv6_bindings3.py` script automates the creation of **static port bindings** for IPv6 EPGs by inheriting the physical port configurations from existing IPv4 EPGs.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  Existing IPv4 EPG (e.g., EPG-V0140)                            │
│  ├── VPC Path: topology/pod-1/protpaths-101-102/pathep-[vpc1]   │
│  ├── VPC Path: topology/pod-1/protpaths-103-104/pathep-[vpc2]   │
│  └── (Physical port bindings for compute hosts)                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ Script copies paths, assigns new VLAN
┌─────────────────────────────────────────────────────────────────┐
│  New IPv6 EPG (e.g., EPG-ACAS-SCANNERS)                         │
│  ├── VPC Path: topology/pod-1/protpaths-101-102/pathep-[vpc1]   │
│  │   └── VLAN: 3192 (IPv6 VLAN)                                 │
│  ├── VPC Path: topology/pod-1/protpaths-103-104/pathep-[vpc2]   │
│  │   └── VLAN: 3192 (IPv6 VLAN)                                 │
│  └── (Same physical connectivity, new IPv6 VLAN encapsulation)  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Features

| Feature | Description |
|---------|-------------|
| **Port Inheritance** | Copies VPC/port paths from IPv4 reference EPGs |
| **VLAN Assignment** | Applies unique IPv6 VLANs (3000+ range) |
| **Dual-Site Support** | Handles both Site1 and Site2 sites |
| **Idempotent** | Safe to run multiple times without duplicates |
| **Dry-Run Mode** | Preview changes before applying |

### EPG Mapping (39 Total)

The script maintains a mapping dictionary that connects each IPv6 EPG to:
- **Reference EPG:** Source IPv4 EPG for port bindings
- **IPv6 VLAN:** Unique VLAN for IPv6 traffic
- **Function Code:** IPv6 subnet identifier

**Sample Mappings:**

| IPv6 EPG | Reference IPv4 EPG | IPv6 VLAN | Function |
|----------|-------------------|-----------|----------|
| EPG-PRINT-SVR | EPG-V3208 | 3208 | d0 |
| EPG-AD | EPG-V3173 | 3173 | ad |
| EPG-DB-SVR | EPG-V3219 | 3219 | db |
| EPG-MECM | EPG-V3236 | 3236 | ec |
| EPG-ACAS-SCANNERS | EPG-V0140 | 3192 | c0 |

---

## 4. Deployment Workflow

```
┌──────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT SEQUENCE                            │
└──────────────────────────────────────────────────────────────────────┘

Step 1: Terraform Plan & Apply
─────────────────────────────────
  $ cd NDO/
  $ terraform plan          # Review changes
  $ terraform apply         # Create BDs, EPGs, Subnets in NDO

         Creates in NDO:
         ├── 10 Bridge Domains
         ├── 39 EPGs
         ├── 43 IPv6 Subnets
         └── Physical Domain Associations

                    │
                    ▼

Step 2: NDO Template Deployment
─────────────────────────────────
  Manual Step: Deploy templates to sites via NDO GUI
  - Deploy L2_Stretched to both sites
  - Deploy Site1-Specific_Only to Site1
  - Deploy Site2-Specific_Only to Site2
  - Deploy L2_Non-Stretched to both sites

                    │
                    ▼

Step 3: Python Script Execution
─────────────────────────────────
  $ python3 generate_ipv6_bindings3.py --dry-run   # Preview
  $ python3 generate_ipv6_bindings3.py             # Apply bindings

         Creates on APIC:
         └── Static port bindings for all 39 EPGs
             (VPCs with IPv6 VLAN encapsulation)
```

---

## 5. Data Validation

### Source of Truth

The IPv6 VLAN assignments are derived from actual VM inventory data:

| Data Source | Contains |
|-------------|----------|
| `IPv6_VMs.csv` | VM names, function codes, assigned VLANs |
| `RCC-E-functioncodes.rtf` | Function ID to purpose mapping |
| `bds_epgs.yaml` | Consolidated configuration with verification flags |

### Validation Status

- **39/39 EPGs** validated against VM inventory
- **20 EPGs** with `verified: true` (VMs actively deployed)
- **19 EPGs** pre-provisioned for future workloads

---

## 6. Network Impact

### What Changes

| Category | Before | After |
|----------|--------|-------|
| Bridge Domains | Existing IPv4 only | + 10 new IPv6 BDs |
| EPGs | Existing IPv4 only | + 39 new IPv6 EPGs |
| Subnets | IPv4 subnets | + 43 IPv6 /56 subnets |
| Port Bindings | IPv4 VLANs | + IPv6 VLANs (dual-stack) |

### What Doesn't Change

- Existing IPv4 infrastructure remains untouched
- No changes to existing contracts or policies
- No changes to physical connectivity
- Existing VMs continue operating on IPv4

---

## 7. Rollback Procedure

If needed, the deployment can be reversed:

```bash
# Remove Terraform-managed objects
$ cd NDO/
$ terraform destroy

# Remove port bindings (if script was run)
$ python3 generate_ipv6_bindings3.py --remove
```

---

## 8. Files Reference

| File | Location | Purpose |
|------|----------|---------|
| `bds_epgs.tf` | `NDO/` | Terraform configuration for NDO objects |
| `generate_ipv6_bindings3.py` | `NDO/` | Python script for port bindings |
| `bds_epgs.yaml` | `NDO/` | Human-readable configuration reference |
| `IPv6_VMs.csv` | `NDO/` | VM inventory with VLAN assignments |
| `DEPLOYMENT_GUIDE.md` | `NDO/` | Step-by-step deployment instructions |

---

## 9. Contact & Support

For questions regarding this deployment:
- Review the detailed `DEPLOYMENT_GUIDE.md` for operational procedures
- Check `bds_epgs.yaml` for configuration details
- VM-to-VLAN mappings are documented in `IPv6_VMs.csv`

---

*This document provides an executive overview. For detailed technical implementation, refer to the source files in the NDO/ directory.*

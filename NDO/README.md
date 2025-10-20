# ⚠️ SECURITY WARNING

**DO NOT COMMIT CREDENTIALS TO THIS REPOSITORY**

The following files contain sensitive information and are excluded via `.gitignore`:
- `terraform.tfvars` - MSO credentials
- `terraform.tfstate*` - May contain sensitive data
- `ipv6_rcc_port_bindings.json` - Generated file, can be recreated
- `.terraform/` - Provider binaries and cache

Always use environment variables or secure credential management for production deployments.

---

# Cisco ACI Multi-Site Orchestrator (MSO) - IPv6 RCC Services Deployment

## Overview

This repository contains Terraform configurations and Python automation scripts for deploying IPv6-enabled Regional Computing Center (RCC) services in Cisco ACI Multi-Site Orchestrator. The solution provides a complete Infrastructure-as-Code (IaC) implementation for network segmentation, policy management, and automated port binding deployment across multiple data center sites.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Repository Structure](#repository-structure)
4. [Deployment Guide](#deployment-guide)
5. [Configuration Details](#configuration-details)
6. [Automation Scripts](#automation-scripts)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)
9. [Known Limitations](#known-limitations)
10. [FAQ](#frequently-asked-questions-faq)

---

## Architecture Overview

### Network Design

This implementation deploys a comprehensive IPv6 network infrastructure with:

- **1 Virtual Routing & Forwarding (VRF)** instance: VRF-RCC
- **33 Bridge Domains** with IPv6 subnets
- **33 Endpoint Groups (EPGs)** for service segmentation
- **Multi-site deployment** across AEDCG (Grafenwoehr) and AEDCK (Kaiserslautern)
- **Template-based organization** for stretched and site-specific resources
- **VLAN range:** 3000-3032

### Service Categories

#### Infrastructure Management (4 EPGs)
- Network Access Control (NAC)
- Configuration Management
- Gateway/External Fabric Management (GEF)
- Microsoft Endpoint Configuration Manager (MECM)

#### Network Services (5 EPGs)
- Load Balancers
- DNS Management
- RCC DNS
- DHCP Servers
- SMTP Mail Servers

#### Voice & Communications (4 EPGs)
- VoIP Management
- VoIP Proxy Services
- Land Mobile Radio (LMR)
- Emergency 911 Services

#### Security Services (4 EPGs)
- ACAS Vulnerability Scanners
- Comply-to-Connect (C2C) Scanners
- OCSP Certificate Validation
- PKI Services

#### Directory & Authentication (2 EPGs)
- Active Directory
- Active Directory Federation Services (ADFS)

#### Proxy Services (3 EPGs)
- D64 Proxy
- Reverse Web Proxy
- Forward Web Proxy

#### Application & Web Servers (3 EPGs)
- Application Servers
- Web Servers
- Firmware Servers

#### RCC Services (3 EPGs)
- RCC Servers
- RCC Data Center Operations
- RCC UNIX Systems

#### Storage Services (3 EPGs)
- Print Servers
- File Servers
- Backup Servers (Kaiserslautern-specific)

#### Database & Logging (2 EPGs)
- Database Servers
- Syslog Servers

---

## Prerequisites

### Software Requirements

- **Terraform** >= 1.0
- **Python** >= 3.7
- **Cisco MSO Terraform Provider** (ciscodevnet/mso)
- **Git** (for version control)

### Required Python Packages

```bash
pip3 install requests urllib3

Network Access

Connectivity to Cisco NDO/MSO controller
API credentials with schema modification permissions
Access to both sites (AEDCG and AEDCK)

Existing Infrastructure

ACI fabric with Multi-Site Orchestrator configured
Existing schema: AEDCE
Sites configured: AEDCG (  Grafenwoehr     = true), AEDCK (Kaiserslautern)
Tenant: EUR
Existing templates:
UpgradeTemplate1 (internal name, display: "VRF_Template")
L2_Stretched
G-Specific_Only
K-Specific_Only
L2_Non-Stretched
Existing "Any" filter in UpgradeTemplate1
Physical domain: PhysDom_ACI_Nexus configured
VPC policy groups configured:
VPC_D1A-B (nodes 111-112)
VPC_D2A-B (nodes 111-112)
VPC_D3A-B (nodes 111-112)
VPC_GEF_A-B (nodes 111-112)


Repository Structure

Copy Code
aci-mso-ipv6-rcc/
├── .gitignore                         # Git exclusion rules
├── README.md                          # This file
├── bds_epgs.tf                       # Main Terraform configuration (~2500 lines)
├── generate_ipv6_bindingsnew.py        # Auto-generates port bindings
├── remove_all_rcc_bindings.py       # Removes existing bindings
└── check_rcc_bindings.py            # Diagnostic tool

Not in repo (excluded by .gitignore):
├── terraform.tfvars                  # Credentials (DO NOT COMMIT)
├── terraform.tfstate*                # State files (DO NOT COMMIT)
├── ipv6_rcc_port_bindings.json      # Generated file
└── .terraform/                       # Provider cache


Deployment Guide

Complete Deployment Workflow

bash
Copy Code
# ============================================================================
# PHASE 1: TERRAFORM DEPLOYMENT (Logical Infrastructure)
# ============================================================================

# 1. Configure credentials
cat > terraform.tfvars << EOF
mso_username = "admin"
mso_password = "your_password"
mso_url      = "https://your-mso-host"
EOF

# 2. Initialize Terraform
terraform init

# 3. Review planned changes
terraform plan

# Expected: ~304 resources to create

# 4. Deploy infrastructure
terraform apply

# Duration: 8-12 minutes
# Creates: VRF, contracts, 33 BDs, 33 EPGs, site associations, domains

# ============================================================================
# PHASE 1.5: MANUAL vzAny CONFIGURATION (REQUIRED)
# ============================================================================

# 5. Configure vzAny in MSO GUI
#
# ⚠️ THIS STEP CANNOT BE AUTOMATED - REQUIRED MANUAL CONFIGURATION
#
# Steps:
#   a. Navigate to: Schemas → AEDCE → UpgradeTemplate1 → VRF-RCC
#   b. Under "vzAny Provider Contracts": Click "+ Contract"
#      - Select: Any_VRF-RCC
#   c. Under "vzAny Consumer Contracts": Click "+ Contract"
#      - Select: Any_VRF-RCC
#   d. Click "Save"
#   e. Click "Deploy" → Select both sites (AEDCG, AEDCK) → Deploy
#
# Duration: 2-3 minutes
# Why Manual? MSO Terraform provider limitation
# One-time: Rarely changes after initial setup

# ============================================================================
# PHASE 2: PYTHON AUTOMATION (Physical Port Bindings)
# ============================================================================

# 6. Check current bindings (optional)
python3 check_rcc_bindings.py

# 7. Remove old/incorrect bindings if needed
python3 remove_all_rcc_bindings.py --dry-run  # Test first
python3 remove_all_rcc_bindings.py            # Actually remove

# 8. Generate accurate bindings
python3 generate_ipv6_bindingsnew.py generate

# Duration: 30-60 seconds
# Output: ipv6_rcc_port_bindings.json

# 9. Review generated bindings
cat ipv6_rcc_port_bindingsnew.json | less

# Verify no management ports
grep -E "paths-10[12]|protpaths-101-102" ipv6_rcc_port_bindings.json
# Should return nothing

# 10. Deploy port bindings
python3 generate_ipv6_bindingsnew.py deploy

# Duration: 30-60 seconds
# Creates: ~200 static port bindings

# ============================================================================
# VERIFICATION
# ============================================================================

# 11. Verify all bindings applied
python3 check_rcc_bindings.py

# Expected: TOTAL BINDINGS ON RCC EPGs: ~200

# 12. Verify in MSO GUI
# - All EPGs exist in correct templates
# - All EPGs have static ports configured
# - vzAny is enabled with contracts


Configuration Details

VRF Configuration

VRF-RCC provides:


Layer 3 routing isolation
vzAny enabled for intra-VRF communication
Context-scoped contract (Any_VRF-RCC)
IPv6 addressing scheme: fd00:10:XX:YY::1/64

⚠️ Important: vzAny contract binding requires manual configuration in MSO GUI (see Phase 1.5)


VLAN Allocation

VLAN Range	Service Type	Count
3000-3003	Infrastructure Management	4
3004-3008	Network Services	5
3009-3012	Voice & Communications	4
3013-3016	Security Services	4
3017-3018	Directory & Authentication	2
3019-3021	Proxy Services	3
3022-3024	Application & Web Servers	3
3025-3027	RCC Services	3
3028-3030	Storage Services	3
3031-3032	Database & Logging	2

Template Distribution

Template	BDs	EPGs	Layer2 Stretch	Sites	Purpose
UpgradeTemplate1	0	0	N/A	N/A	VRF and contracts only
L2_Stretched	29	29	Yes	Both	Production services stretched across sites
G-Specific_Only	1	1	No*	AEDCG	  Grafenwoehr     = true-specific (GEF Management)
K-Specific_Only	1	1	No*	AEDCK	Kaiserslautern-specific (Backup Services)
L2_Non-Stretched	2	2	No*	Both	Site-local (Database, Logging)

*Note: layer2_stretch = true in config enables routing, but site associations control actual stretching


Bridge Domain Features

All BDs configured with:


✅ Unicast Routing - Layer 3 routing enabled
✅ Host Route - Advertises /128 host routes for endpoints
✅ Intersite BUM Traffic - Enabled for L2_Stretched only
✅ Optimize WAN Bandwidth - Enabled for L2_Stretched only
✅ EP Move Detection - GARP-based for stretched BDs
✅ Layer2 Unknown Unicast - Proxy mode
✅ Subnet Scope - Public and shared
✅ Physical Domain - PhysDom_ACI_Nexus association

Port Binding Patterns

Standard Production Pattern (Most EPGs)

Copy Code
AEDCG Site:
  - VPC_D1A-B (nodes 111-112)
  - VPC_D2A-B (nodes 111-112)

AEDCK Site:
  - VPC_D1A-B (nodes 111-112)
  - VPC_D2A-B (nodes 111-112)
  - VPC_D3A-B (nodes 111-112)

GEF Management Pattern (EPG-GEF-MGMT only)

Copy Code
AEDCG Site only:
  - VPC_D1A-B (nodes 111-112)
  - VPC_D2A-B (nodes 111-112)
  - VPC_GEF_A-B (nodes 111-112) ← External gateway

Exclusions (Filtered Out)

❌ paths-101 (individual leaf 101)
❌ paths-102 (individual leaf 102)
❌ protpaths-101-102 (VPC_Transport)
✅ Production traffic only on nodes 111-112


Automation Scripts

generate_ipv6_bindingsnew.py

Purpose: Auto-generates port bindings for IPv6 RCC EPGs based on existing IPv4 infrastructure.


Key Features:


✅ Auto-discovers RCC EPGs across all templates
✅ Intelligent mapping to functionally similar IPv4 EPGs
✅ Filters out management ports (leaves 101/102, VPC_Transport)
✅ Handles multi-site deployment
✅ Site-aware template placement
✅ Future-proof: automatically detects new EPGs

Usage:


bash
Copy Code
python3 generate_ipv6_bindingsnew.py generate    # Generate JSON only
python3 generate_ipv6_bindingsnew.py deploy      # Generate and deploy
python3 generate_ipv6_bindingsnew.py             # Generate with prompt

Output: ipv6_rcc_port_bindings.json


IPv4 to IPv6 EPG Mapping:


IPv6 EPG	VLAN	Maps to IPv4	Purpose
EPG-NAC	3000	EPG-V0015	Network Access Control
EPG-CFG-MGMT	3001	EPG-V0021	Configuration Management
EPG-GEF-MGMT	3002	EPG-V0260	Gateway Management (includes VPC_GEF_A-B)
EPG-MECM	3003	EPG-V0033	Endpoint Management
EPG-LB	3004	EPG-V0210	Load Balancers
EPG-DNS-MGMT	3005	EPG-V0216	DNS Management
EPG-RCC-DNS	3006	EPG-V0218	RCC DNS
EPG-DHCP-SVR	3007	EPG-V0219	DHCP Servers
EPG-SMTP-SVR	3008	EPG-V0220	Mail Servers
EPG-VVOIP-MGMT	3009	EPG-V0160	VoIP Management
EPG-VVOIP-PROXY	3010	EPG-V0161	VoIP Proxy
EPG-LMR	3011	EPG-V0163	Land Mobile Radio
EPG-E911-SVR	3012	EPG-V0178	Emergency 911
EPG-ACAS-SCANNERS	3013	EPG-V0140	Vulnerability Scanners
EPG-C2C-SCANNERS	3014	EPG-V0141	Compliance Scanners
EPG-OCSP	3015	EPG-V0142	Certificate Validation
EPG-PKI-SRV	3016	EPG-V0144	PKI Infrastructure
EPG-AD	3017	EPG-V0150	Active Directory
EPG-ADFS	3018	EPG-V0160	ADFS
EPG-D64-PROXY	3019	EPG-V0260	D64 Proxy
EPG-RWEB-PROXY	3020	EPG-V0261	Reverse Proxy
EPG-FWEB-PROXY	3021	EPG-V0262	Forward Proxy
EPG-APP-SVR	3022	EPG-V0420	Application Servers
EPG-WEB-SVR	3023	EPG-V0420	Web Servers
EPG-FMWR-SVR	3024	EPG-V0450	Firmware Servers
EPG-RCC-SVR	3025	EPG-V0470	RCC Servers
EPG-RCC-DCO	3026	EPG-V0471	Data Center Ops
EPG-RCC-UNIX	3027	EPG-V0472	UNIX Systems
EPG-PRINT-SVR	3028	EPG-V0520	Print Servers
EPG-FILE-SVR	3029	EPG-V0521	File Servers
EPG-BACKUP-SVR	3030	EPG-V0522	Backup Servers
EPG-DB-SVR	3031	EPG-V0570	Database Servers
EPG-SYSLOG	3032	EPG-V0572	Syslog Servers


remove_all_rcc_bindings.py

Purpose: Removes all static port bindings from RCC EPGs.


Features:


Targets only AppProf-RCC EPGs
Leaves IPv4 EPGs untouched
Dry-run mode for safety
Handles authentication token refresh

Usage:


bash
Copy Code
python3 remove_all_rcc_bindings.py --dry-run  # Test mode
python3 remove_all_rcc_bindings.py            # Actually delete


check_rcc_bindings.py

Purpose: Diagnostic tool to view current RCC EPG bindings.


Features:


Lists all static port bindings on RCC EPGs
Shows site, template, EPG, path, and VLAN
Non-destructive read-only operation

Usage:


bash
Copy Code
python3 check_rcc_bindings.py

Sample Output:


Copy Code
AEDCG/L2_Stretched/EPG-NAC
  Static ports: 2
    - Path: topology/pod-1/protpaths-111-112/pathep-[VPC_D1A-B], VLAN: 3000
    - Path: topology/pod-1/protpaths-111-112/pathep-[VPC_D2A-B], VLAN: 3000

TOTAL BINDINGS ON RCC EPGs: 200


Manual Configuration Steps

vzAny Contract Binding (Required)

⚠️ CRITICAL MANUAL STEP - Cannot be automated with current Terraform provider


When: After Terraform deployment completes
Duration: 2-3 minutes
Frequency: One-time setup


Why Required: The MSO Terraform provider's mso_schema_template_vrf_contract resource is designed for EPG-to-EPG contracts across VRFs, not for vzAny contract binding within a VRF. This is a known provider limitation.


Step-by-Step Instructions:


Login to MSO GUI

URL: https://your-mso-host
Use admin credentials
Navigate to VRF:

Copy Code
Main Menu → Application Management → Schemas
→ Schema: AEDCE
→ Template: UpgradeTemplate1 (display name: "VRF_Template")
→ Click: VRF-RCC
Add Provider Contract:

Section: "vzAny Provider Contracts"
Click: "+ Contract" button
Select from dropdown: Any_VRF-RCC
Verify contract appears in list
Add Consumer Contract:

Section: "vzAny Consumer Contracts"
Click: "+ Contract" button
Select from dropdown: Any_VRF-RCC
Verify contract appears in list
Save Configuration:

Click "Save" button (top-right)
Wait for confirmation message
Deploy to Sites:

Click "Deploy" button (top-right)
Check both sites:
☑ AEDCG
☑ AEDCK
Click "Deploy" button
Monitor deployment progress
Wait for "Deployment Successful" message
Verify Configuration:

Navigate back to: VRF-RCC
Confirm:
✅ vzAny checkbox is checked
✅ Provider Contracts: Any_VRF-RCC
✅ Consumer Contracts: Any_VRF-RCC

What This Enables:


All EPGs within VRF-RCC can communicate with each other
Traffic permitted in both directions (provider + consumer)
"Any" filter allows all protocols and ports

Troubleshooting:


If checkbox is grayed out: Save VRF first, then refresh browser
If contract not in dropdown: Verify Any_VRF-RCC exists in UpgradeTemplate1
If deployment fails: Check inter-site connectivity


IPv6 Addressing Scheme

Address Allocation Pattern

Copy Code
fd00:10:XX:YY::1/64

Components:
  fd00:      = IPv6 ULA (Unique Local Address) prefix
  10:        = Organization identifier
  XX:        = Service category (10-A0)
  YY:        = Specific service identifier  
  ::1        = Gateway address
  /64        = Standard IPv6 subnet size

Address Ranges by Service Category

Service Category	Prefix	Range	Example
Infrastructure Mgmt	fd00:10:10::/48	15-ef	fd00:10:10:15::1/64 (NAC)
Network Services	fd00:10:20::/48	1b-d5	fd00:10:20:53::1/64 (DNS)
Voice/Communications	fd00:10:30::/48	41-e9	fd00:10:30:41::1/64 (VoIP)
Security Services	fd00:10:40::/48	c0-ca	fd00:10:40:c0::1/64 (ACAS)
Directory/Auth	fd00:10:50::/48	ad-af	fd00:10:50:ad::1/64 (AD)
Proxy Services	fd00:10:60::/48	d6-d8	fd00:10:60:d6::1/64 (D64)
App/Web Servers	fd00:10:70::/48	e0-e4	fd00:10:70:e0::1/64 (App)
RCC Services	fd00:10:80::/48	bc-bf	fd00:10:80:bc::1/64 (RCC)
Storage Services	fd00:10:90::/48	d0-dd	fd00:10:90:d0::1/64 (Print)
Data/Logging	fd00:10:a0::/48	d9-db	fd00:10:a0:db::1/64 (DB)


Architecture Decisions

Why Single VRF?

Pros:


✅ Simplified routing - single routing table
✅ Reduced complexity - easier to manage
✅ Better performance - less policy overhead
✅ Easier troubleshooting - single domain

Trade-offs:


⚠️ Less micro-segmentation (mitigated by BD isolation)
⚠️ All services in same routing domain (acceptable for trusted RCC services)

Why 33 Bridge Domains?

Rationale:


✅ One BD per EPG = maximum flexibility
✅ Independent subnet management per service
✅ Isolated broadcast domains
✅ Can move EPGs between BDs without affecting others
✅ Future-ready for EPG-to-EPG contracts if needed

Why Filter Management Ports?

Decision: Exclude leaves 101/102 and VPC_Transport


Reasons:


✅ Clean separation: production traffic on production nodes (111-112)
✅ Security boundary: management plane separate from data plane
✅ Simplified troubleshooting: predictable port assignments
✅ Matches existing architecture patterns


Known Limitations

1. vzAny Contract Binding (Manual Configuration Required)

Limitation: MSO Terraform provider cannot bind contracts to vzAny
Impact: 2-3 minutes of manual GUI configuration required
Workaround: Follow Phase 1.5 in deployment guide
Frequency: One-time (rarely changes)
Severity: Low - well-documented, quick to configure


Technical Details:


The mso_schema_template_vrf_contract resource exists but doesn't bind to vzAny
Resource is intended for EPG-to-EPG contracts across VRFs
Provider maintainers aware of limitation
No ETA for fix as of Oct 2025

2. Static Port Binding Performance

Limitation: Terraform is slow for port bindings (10-15 minutes)
Impact: Extended deployment time if using Terraform for bindings
Workaround: Use Python script (30-60 seconds)
Severity: Medium - affects deployment speed only


3. Template-Level Stretch Flag

Quirk: Must set layer2_stretch = true even for non-stretched BDs
Reason: Required by API to enable subnets/routing
Impact: None - actual stretching controlled by site associations
Workaround: Set flag, control stretching via template placement



Troubleshooting

Terraform Errors

"Duplicate Resource"

Copy Code
Error: VRF VRF-RCC already exists

Solution:
1. Import existing resource:
   terraform import mso_schema_template_vrf.vrf_rcc <schema_id>/UpgradeTemplate1/VRF-RCC

2. Or delete from MSO GUI and re-run terraform apply

"replace operation does not apply"

Copy Code
Error: doc is missing key: /templates/X/bds/Y/...

Solution (Lab only):
rm -f terraform.tfstate*
terraform apply

"Subnets defined on non-stretched BD"

Copy Code
Solution: Set layer2_stretch = true on all BDs with subnets
(Enables L3 routing, doesn't actually stretch)

"Domain PhysDom_ACI_Nexus not found"

Copy Code
Solution:
1. Verify domain exists in APIC: Fabric → Access Policies → Domains
2. Check spelling matches exactly
3. Verify domain is associated with AEPs


Python Script Errors

No RCC EPGs Found

Copy Code
Error: ✗ No RCC EPGs found in schema!

Solution:
1. Run terraform apply first
2. Verify EPGs exist: Schemas → AEDCE → L2_Stretched → AppProf-RCC
3. Wait 1-2 minutes for synchronization

Authentication Failed

Copy Code
Error: ✗ Authentication failed

Solution:
1. Verify NDO_HOST is correct (IP or hostname)
2. Check credentials in script
3. Test login via MSO GUI
4. Verify network connectivity: ping <NDO_HOST>

Reference EPG Not Found

Copy Code
Warning: Reference EPG not found, using defaults

Impact: Script uses default VPC pattern instead
Solution: Verify reference IPv4 EPG exists and has port bindings
Workaround: Default pattern usually sufficient (VPC_D1A-B + VPC_D2A-B)


vzAny Issues

EPGs Cannot Communicate

Copy Code
Symptom: Endpoints in different EPGs cannot ping each other

Checklist:
1. Verify vzAny enabled: VRF-RCC → vzAny checkbox checked
2. Verify contracts assigned:
   - Provider: Any_VRF-RCC present
   - Consumer: Any_VRF-RCC present
3. Verify contract has filter: Any_VRF-RCC → Filter: Any
4. Verify schema deployed to both sites
5. Check endpoint learning: APIC → Tenants → EUR → VRF-RCC → Endpoints
6. Verify subnets in routing table: VRF-RCC → Routes

vzAny Checkbox Grayed Out

Copy Code
Solution:
1. Save VRF configuration first
2. Refresh browser (Ctrl+F5)
3. Check user permissions for schema modification
4. Verify VRF was created successfully


Maintenance

Adding New EPGs (Future-Proof Design)

The automation is designed to handle new EPGs automatically:


Steps:


Add resources to Terraform (BD, subnet, EPG, site associations, domains)
Run terraform apply
Run python3 generate_ipv6_bindingsnew.py deploy
Script auto-discovers new EPG and applies port pattern

Example:


hcl
Copy Code
# New BD
resource "mso_schema_template_bd" "bd_new_service" {
  name          = "BD-NEW-SERVICE"
  vrf_name      = mso_schema_template_vrf.vrf_rcc.name
  # ... standard BD configuration ...
}

# New EPG
resource "mso_schema_template_anp_epg" "epg_new_service" {
  name    = "EPG-NEW-SERVICE"
  bd_name = mso_schema_template_bd.bd_new_service.name
}

# Site associations, site BDs, domains (follow existing pattern)

No script modifications needed!



Modifying Port Bindings

To change which IPv4 EPG is used as reference:


Edit generate_ipv6_bindingsnew.py:


python
Copy Code
self.epg_mapping = {
    'EPG-NAME': {
        'reference': 'EPG-V0XXX',  # Change reference
        'vlan': 3000,
        'template': 'L2_Stretched'
    }
}

Then:


bash
Copy Code
python3 remove_all_rcc_bindings.py
python3 generate_ipv6_bindingsnew.py deploy


Backup Procedures

Before major changes:


bash
Copy Code
# Backup Terraform state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)

# Export MSO schema
# GUI: Schemas → AEDCE → Export

# Commit to Git
git add -A
git commit -m "Backup before changes"
git push


Performance Metrics

Phase	Duration	Method
Terraform Infrastructure	8-12 min	Terraform apply
vzAny Configuration	2-3 min	Manual GUI
Port Binding Generation	30-60 sec	Python script
Port Binding Deployment	30-60 sec	Python API
Total End-to-End	~15 min	Hybrid approach

Comparison: Terraform vs Python for Port Bindings


Terraform: 10-15 minutes (sequential API calls)
Python: 30-60 seconds (batch operations)
Speed improvement: 20x faster with Python


Security Considerations

Network Isolation

✅ VRF-RCC isolated from other VRFs
✅ 33 separate broadcast domains (BD isolation)
✅ VLAN separation (3000-3032)
✅ vzAny with "Any" filter for intra-VRF communication
✅ No routes to/from other VRFs by default

High Availability

✅ Dual VPC paths (D1A-B + D2A-B minimum)
✅ Node redundancy (111-112 pairs)
✅ Site redundancy (AEDCG + AEDCK)
✅ No single points of failure

Access Control

✅ Physical domain association required for port access
✅ Static port bindings explicitly defined
✅ vzAny can be enhanced with specific contracts if needed


Git Repository Setup

Initial Setup

This repository should be treated as internal/private due to infrastructure configuration details.


Files to Commit

✅ Include in Git:


README.md - This documentation
.gitignore - Exclusion rules
bds_epgs.tf - Terraform configuration
generate_ipv6_bindingsnew.py - Binding generator
remove_all_rcc_bindings.py - Cleanup script
check_rcc_bindings.py - Diagnostic script

❌ Exclude from Git (via .gitignore):


terraform.tfvars - Contains credentials
terraform.tfstate* - Contains sensitive data
ipv6_rcc_port_bindings.json - Generated file
.terraform/ - Provider cache
Any files with "password", "secret", or "token" in name

Git Commands for Initial Commit

bash
Copy Code
# Create .gitignore (see Prerequisites section)
# Create README.md (this file)

# Initialize repository
git init

# Add files
git add .gitignore
git add README.md
git add bds_epgs.tf
git add *.py

# CRITICAL: Verify no sensitive files
git status
# Should NOT show: .tfvars, .tfstate, or credential files

# Commit
git commit -m "Initial commit: IPv6 RCC services deployment automation"

# Add remote (replace with your repo URL)
git remote add origin https://github.com/your-org/aci-mso-ipv6-rcc.git

# Push
git branch -M main
git push -u origin main


Resource Summary

Terraform-Managed

Resource Type	Count
VRF	1
Contracts	1
Bridge Domains	33
BD Subnets	33
Site BDs (host_route)	62
Application Profiles	3
EPGs	33
Site ANP Associations	6
Site EPG Associations	66
EPG Domain Associations	66
Total	304

Manually Configured

Resource Type	Count	Location
vzAny Contract Bindings	2	VRF-RCC (provider + consumer)

Python-Managed

Resource Type	Count
Static Port Bindings	~200

Grand Total: 506 configuration items



Frequently Asked Questions (FAQ)

Q: Why can't Terraform configure vzAny?
A: MSO Terraform provider limitation. The resource exists but doesn't work for vzAny. Manual GUI configuration is required (one-time, 2-3 minutes).


Q: Why use Python instead of Terraform for port bindings?
A: Python is 20x faster (30 seconds vs 10 minutes) due to batch API operations.


Q: Are the port paths really identical at both sites?
A: Yes, VPC policy group names (VPC_D1A-B, etc.) are logical names that reference site-specific physical configurations.


Q: Why filter out leaves 101/102?
A: These are management/edge nodes. Production traffic should use production fabric nodes (111-112).


Q: Can I add more EPGs later?
A: Yes! Add to Terraform, run terraform apply, then run Python script. Auto-discovers new EPGs.


Q: What if I need different security policies?
A: Add EPG-to-EPG contracts in addition to vzAny. vzAny provides baseline connectivity.


Q: How do I rollback?
A: Lab: terraform destroy then redeploy. Production: Use terraform state management and selective removal.


Q: Do I need to configure vzAny every Terraform run?
A: No! One-time configuration. Future Terraform runs don't affect vzAny settings.



Support & Contact

For Issues:

Check Troubleshooting section
Review script output and error messages
Verify Prerequisites are met
Check MSO Audit Logs: Application Management → Operations → Audit Logs
Contact network infrastructure team

When Reporting Issues Include:

Terraform version: terraform version
Python version: python3 --version
Full error messages
Script output (if applicable)
Whether vzAny was manually configured
Screenshots of MSO GUI (if relevant)


License

Internal use only - Cisco proprietary infrastructure configuration



Authors & Acknowledgments

Network Infrastructure Team
Deployment Date: October 2025
Last Updated: October 2025
Documentation Version: 1.0


Quick Reference Card

Essential Commands

bash
Copy Code
# Terraform
terraform init && terraform plan && terraform apply

# vzAny (Manual - see Phase 1.5)
# GUI: Schemas → AEDCE → UpgradeTemplate1 → VRF-RCC

# Python
python3 check_rcc_bindings.py
python3 generate_ipv6_bindingsnew.py generate
python3 generate_ipv6_bindingsnew.py deploy
python3 remove_all_rcc_bindings.py --dry-run

Critical Files

bds_epgs.tf - Infrastructure definition
generate_ipv6_bindingsnew.py - Port automation
terraform.tfvars - Credentials (NOT IN REPO)

Key Resources

Schema: AEDCE
Sites: AEDCG (  Grafenwoehr     = true), AEDCK (Kaiserslautern)
VRF: VRF-RCC (UpgradeTemplate1)
VLANs: 3000-3032
Domain: PhysDom_ACI_Nexus

Don't Forget

Configure vzAny manually after Terraform
Verify no sensitive files before git push
Test in lab before production


END OF README


Copy Code

---

## Now Follow These Steps:

```bash
# 1. Create README.md
cd /Users/johbarbe/Documents/terraform_redesign_esg/NDO
nano README.md

# 2. Paste all the content above (copy from "# ⚠️ SECURITY WARNING" to "END OF README")

# 3. Save and exit (Ctrl+X, then Y, then Enter in nano)

# 4. Verify it was created
ls -la README.md
wc -l README.md  # Should show ~800+ lines

# 5. View first few lines to verify
head -20 README.md

# Executive Summary: IPv6 RCC Infrastructure Automation

## Document Purpose

This document provides an executive-level overview of the automated IPv6 Regional Computing Center (RCC) infrastructure deployment system, specifically covering two key files:
1. `bds_epgs.tf` - Terraform Infrastructure Configuration
2. `generate_ipv6_bindings3.py` - Python Port Binding Automation

---

## System Overview

This solution automates the deployment of IPv6-enabled network infrastructure across two data center sites using Cisco ACI Multi-Site Orchestrator (MSO/NDO). The system creates logical network segments (Bridge Domains and Endpoint Groups) and automatically configures physical port bindings.

### Key Benefits

| Benefit | Description |
|---------|-------------|
| **Automation** | Eliminates manual configuration of 39+ network segments |
| **Consistency** | Ensures identical configuration across both sites |
| **Speed** | Deploys in ~15 minutes vs. hours of manual work |
| **Auditability** | Infrastructure-as-Code provides version control and change tracking |
| **Scalability** | Easy to add new services by following established patterns |

---

## File 1: bds_epgs.tf (Terraform Configuration)

### What It Does

Defines and deploys the **logical network infrastructure** to Cisco NDO:

| Component | Count | Description |
|-----------|-------|-------------|
| **VRF** | 1 | Virtual Routing & Forwarding instance (VRF-RCC) |
| **Bridge Domains** | 39 | Layer 2 network segments with IPv6 subnets |
| **EPGs** | 39 | Endpoint Groups for policy enforcement |
| **Contracts** | 1 | Security policy (Any_VRF-RCC) |
| **Site Associations** | ~150 | Multi-site deployment mappings |

### IPv6 Addressing Scheme

Each service has a unique IPv6 subnet based on its function code:

```
Format: [function_code]00::1/56

Examples:
  Function 15 (NAC)     → 1500::1/56
  Function 66 (VHOST)   → 6600::1/56
  Function c0 (ACAS)    → c000::1/56
```

### Service Categories Deployed

| Category | EPGs | Examples |
|----------|------|----------|
| Infrastructure Management | 6 | NAC, MECM, NMS, CFG-MGMT |
| Network Services | 5 | DNS, DHCP, SMTP, Load Balancers |
| Security Services | 5 | ACAS, C2C, PKI, OCSP |
| Voice/Communications | 4 | VoIP, LMR, E911 |
| Directory Services | 2 | Active Directory, ADFS |
| Proxy Services | 3 | D64, Web Proxies |
| Application Servers | 4 | App, Web, Firmware, Patch |
| RCC Services | 4 | RCC Servers, DCO, UNIX, ADM-DCO |
| Storage Services | 3 | Print, File, Backup |
| Database/Logging | 2 | Database, Syslog |

### Template Distribution

| Template | Purpose | Sites |
|----------|---------|-------|
| L2_Stretched | Production services | Both (G & K) |
| Site1-Specific_Only | Site G exclusive services | Grafenwoehr only |
| Site2-Specific_Only | Site K exclusive services | Kaiserslautern only |
| L2_Non-Stretched | Site-local services | Both (non-stretched) |

### Deployment Command

```bash
terraform init
terraform plan
terraform apply
```

**Duration:** 8-12 minutes

---

## File 2: generate_ipv6_bindings3.py (Python Automation)

### What It Does

Automates the **physical port binding** configuration for IPv6 EPGs:

1. **Discovers** all IPv6 RCC EPGs deployed by Terraform
2. **Extracts** port bindings from existing IPv4 reference EPGs
3. **Generates** equivalent IPv6 bindings with correct VLANs
4. **Deploys** bindings to NDO via API

### Key Features

| Feature | Description |
|---------|-------------|
| **Intelligent Mapping** | Maps IPv6 EPGs to functionally similar IPv4 EPGs |
| **VLAN Management** | Assigns verified VLANs based on actual deployment data |
| **Dry-Run Mode** | Preview changes without deployment |
| **Schema Backup** | Creates backup before making changes |
| **Error Handling** | Graceful failure with rollback capability |

### How It Works

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  IPv4 EPG       │     │  Python Script  │     │  IPv6 EPG       │
│  (EPG-V0015)    │────▶│  Copies Ports   │────▶│  (EPG-NAC)      │
│  VPC_D1A-B      │     │  + Assigns VLAN │     │  VPC_D1A-B      │
│  VPC_D2A-B      │     │                 │     │  VPC_D2A-B      │
└─────────────────┘     └─────────────────┘     │  VLAN: 3021     │
                                                └─────────────────┘
```

### EPG Mapping Logic

The script contains a manual mapping table that associates each IPv6 EPG with:
- **Reference EPG**: The IPv4 EPG to copy port bindings from
- **VLAN**: The VLAN ID for the IPv6 traffic
- **Function Code**: The hex identifier for the service
- **Subnet**: The IPv6 subnet

Example mapping:
```python
'EPG-NAC': {
    'reference': 'EPG-V0015',    # Copy bindings from this IPv4 EPG
    'vlan': 3021,                # Use this VLAN
    'function': '15',            # Function code
    'subnet': '1500::/56'        # IPv6 subnet
}
```

### Port Binding Patterns

| Site | Standard VPCs | Notes |
|------|---------------|-------|
| Site G (Grafenwoehr) | VPC_D1A-B, VPC_D2A-B | Nodes 101-102 |
| Site K (Kaiserslautern) | VPC_D1A-B, VPC_D2A-B, VPC_D3A-B | Nodes 101-102 |

### Usage Commands

```bash
# Generate bindings only (no deployment)
python3 generate_ipv6_bindings3.py generate

# Generate and deploy
python3 generate_ipv6_bindings3.py deploy

# Dry-run mode (preview only)
python3 generate_ipv6_bindings3.py dry-run
```

**Duration:** 30-60 seconds

---

## Complete Deployment Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT WORKFLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. TERRAFORM DEPLOYMENT (8-12 min)                            │
│     ┌─────────────────────────────────────────────────────┐    │
│     │  terraform apply                                     │    │
│     │  Creates: VRF, BDs, EPGs, Contracts, Site Assocs    │    │
│     └─────────────────────────────────────────────────────┘    │
│                           │                                     │
│                           ▼                                     │
│  2. MANUAL vzAny CONFIG (2-3 min) - ONE TIME                   │
│     ┌─────────────────────────────────────────────────────┐    │
│     │  MSO GUI: Add vzAny contracts to VRF-RCC            │    │
│     └─────────────────────────────────────────────────────┘    │
│                           │                                     │
│                           ▼                                     │
│  3. PYTHON BINDING GENERATOR (30-60 sec)                       │
│     ┌─────────────────────────────────────────────────────┐    │
│     │  python3 generate_ipv6_bindings3.py deploy          │    │
│     │  Creates: ~200 static port bindings                 │    │
│     └─────────────────────────────────────────────────────┘    │
│                           │                                     │
│                           ▼                                     │
│  4. VERIFICATION                                                │
│     ┌─────────────────────────────────────────────────────┐    │
│     │  python3 check_rcc_bindings.py                      │    │
│     │  Verify in MSO/APIC GUI                             │    │
│     └─────────────────────────────────────────────────────┘    │
│                                                                 │
│  TOTAL TIME: ~15 minutes                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Resource Summary

### Terraform-Managed Resources

| Resource Type | Count |
|---------------|-------|
| VRF | 1 |
| Contracts | 1 |
| Bridge Domains | 39 |
| BD Subnets | 39 |
| Application Profiles | 3 |
| EPGs | 39 |
| Site Associations | ~150 |
| Domain Associations | ~80 |
| **Total** | **~350** |

### Python-Managed Resources

| Resource Type | Count |
|---------------|-------|
| Static Port Bindings | ~200 |

### Combined Total

**~550 configuration items** deployed automatically

---

## Security Considerations

| Aspect | Implementation |
|--------|----------------|
| **Network Isolation** | VRF-RCC isolated from other VRFs |
| **Broadcast Isolation** | 39 separate bridge domains |
| **VLAN Separation** | Unique VLAN per service (3000-3500 range) |
| **Access Control** | vzAny contract for intra-VRF communication |
| **Credential Security** | Environment variables or secure input |

---

## Future Modifications

### Adding New Services

1. Add BD/EPG to Terraform file
2. Add mapping to Python script's `epg_mapping` dictionary
3. Run `terraform apply` then `python3 generate_ipv6_bindings3.py deploy`

### Changing VLANs

1. Update VLAN in Python script's `epg_mapping`
2. Re-run `python3 generate_ipv6_bindings3.py deploy`

### Scaling to New Sites

1. Add site data sources to Terraform
2. Add site associations for BDs and EPGs
3. Add provider configuration for new APIC (if using direct APIC management)

---

## Contact & Support

For issues or modifications:
1. Review Troubleshooting section in README.md
2. Check MSO Audit Logs: Application Management → Operations → Audit Logs
3. Contact Network Infrastructure Team

---

*Document Version: 1.0*  
*Last Updated: January 2026*

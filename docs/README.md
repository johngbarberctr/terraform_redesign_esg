# RCC-E IPv6 Infrastructure - NDO/Terraform Deployment

## Overview

This project deploys IPv6 infrastructure for RCC-E (Regional Cyber Center - Europe) across two ACI sites managed by Nexus Dashboard Orchestrator (NDO):

- **Site1** - Site G (Grafenwoehr)
- **Site2** - Site K (Kaiserslautern)

The deployment creates 39 Bridge Domains, 39 EPGs, L3Outs, External EPGs, and associated contracts within the `VRF-RCC` routing domain.

---

## Architecture

```
                              ┌─────────────────────────────────────┐
                              │      Nexus Dashboard Orchestrator   │
                              │           (Schema: AFRICOM)           │
                              └─────────────────┬───────────────────┘
                                                │
                    ┌───────────────────────────┴───────────────────────────┐
                    │                                                       │
            ┌───────▼───────┐                                       ┌───────▼───────┐
            │   Site G      │                                       │   Site K      │
            │   (Site1)     │                                       │   (Site2)     │
            └───────┬───────┘                                       └───────┬───────┘
                    │                                                       │
        ┌───────────┴───────────┐                           ┌───────────────┴───────────┐
        │                       │                           │                           │
   ┌────▼────┐            ┌─────▼─────┐               ┌─────▼─────┐             ┌───────▼───────┐
   │ 101/102 │            │ 111/112   │               │ 111/112   │             │   101/102     │
   │ Border  │            │ Compute   │               │ Compute   │             │   Border      │
   │ Leaves  │            │ Leaves    │               │ Leaves    │             │   Leaves      │
   └────┬────┘            └─────┬─────┘               └─────┬─────┘             └───────┬───────┘
        │                       │                           │                           │
   PC_DC_FTD_A/B          ┌─────▼─────┐               ┌─────▼─────┐              PC_DC_FTD_A/B
   (L3Out to FW)          │ 101/102   │               │ 101/102   │              (L3Out to FW)
                          │ Compute   │               │ Compute   │
                          │ Leaves    │               │ Leaves    │
                          └───────────┘               └───────────┘
```

### Leaf Roles

| Leaves | Role | Bindings |
|--------|------|----------|
| **101/102** | Border leaves | L3Out to firewall via PC_DC_FTD_A/B, limited EPG bindings |
| **111/112** | Compute leaves | Mirrored with 101/102 |
| **101/102** | Compute leaves | Mirrored with 111/112 |

---

## Templates

| Template | Purpose | Sites |
|----------|---------|-------|
| `UpgradeTemplate1` | VRF and Contract definitions | Both |
| `L2_Stretched` | L2 stretched BDs/EPGs (majority) | Both |
| `L2_Non-Stretched` | Non-stretched BDs/EPGs | Both |
| `Site1-Specific_Only` | Site G specific resources | Site1 only |
| `Site2-Specific_Only` | Site K specific resources | Site2 only |

---

## Files

### Terraform Configuration

| File | Description |
|------|-------------|
| `bds_epgs.tf` | 39 Bridge Domains, 39 EPGs, Site-local BD configs, Subnets |
| `l3outs_ndo.tf` | L3Outs, External EPGs, Contract associations, BD-L3Out bindings |
| `l3outs_apic.tf.disabled` | APIC-level L3Out config (node/interface profiles) - enable after NDO deploy |
| `variables.tf` | Input variables |
| `terraform.tfvars` | Variable values |

### Python Scripts

| File | Description |
|------|-------------|
| `generate_ipv6_bindings3.py` | Generates and deploys static port bindings for IPv6 EPGs |
| `remove_all_rcc_bindings.py` | Removes IPv6 static port bindings (batch mode) |
| `check_rcc_bindings.py` | Verifies current binding status |

---

## VMware Integration (VMM Domain)

VMware integration is configured on the APIC by creating a VMM domain and
associating it to the vCenter. NDO then references that existing VMM domain
when attaching EPGs. Set the VMM domain name in `terraform.tfvars`:

```hcl
vmm_domain_name = "VMM-VMWare-CHANGE_ME"
```

**IPv6 greenfield:** Keep IPv6 separate from IPv4. This repo currently defines
IPv6-only NAC. If you later add IPv4, create a separate IPv4 NAC BD/EPG and
attach the same VMM domain.

---

## IPv6 Objects Created

### Core Infrastructure

| Object | Name | Template |
|--------|------|----------|
| VRF | `VRF-RCC` | UpgradeTemplate1 |
| Contract | `Any_VRF-RCC` | UpgradeTemplate1 |
| L3Out (Site G) | `L3Out-RCC-E-G` | Site1-Specific_Only |
| L3Out (Site K) | `L3Out-RCC-E-K` | Site2-Specific_Only |
| External EPG (Site G) | `ExtEPG-RCC-E-G` | Site1-Specific_Only |
| External EPG (Site K) | `ExtEPG-RCC-E-K` | Site2-Specific_Only |

### Bridge Domains & EPGs (39 total)

#### L2_Stretched Template (35 BDs/EPGs)

| BD/EPG Name | Function Code | IPv6 VLAN | Description |
|-------------|---------------|-----------|-------------|
| NAC | 15 | 3021 | Network Access Control |
| CFG-MGMT | 69 | 3105 | Configuration Management |
| MECM | ec | 3236 | Microsoft Endpoint Config Manager |
| NMS | 01 | 3001 | Network Management System |
| VHOST-MGMT | 66 | 3102 | Virtual Host Management |
| SYSMAN | c3 | 3195 | System Management |
| PATCH | e6 | 3230 | Patch Management |
| LB | 1b | 3050 | Load Balancer |
| DNS-MGMT | 53 | 3083 | DNS Management |
| RCC-DNS | bd | 3051 | RCC DNS Services |
| DHCP-SVR | d2 | 3210 | DHCP Server |
| SMTP-SVR | d5 | 3213 | SMTP Server |
| VVOIP-MGMT | 40 | 3064 | Voice/VoIP Management |
| VVOIP-PROXY | 41 | 3065 | Voice/VoIP Proxy |
| LMR | cb | 3052 | Land Mobile Radio |
| E911-SVR | e9 | 3053 | E911 Server |
| ACAS-SCANNERS | c0 | 3192 | ACAS Scanners |
| C2C-SCANNERS | c1 | 3442 | C2C Scanners |
| OCSP | c5 | 3197 | Online Certificate Status Protocol |
| PKI-SRV | ca | 3054 | PKI Server |
| ACAS-MGMT | c6 | 3198 | ACAS Management |
| AD | ad | 3173 | Active Directory |
| ADFS | af | 3175 | AD Federation Services |
| D64-PROXY | d6 | 3055 | DNS64 Proxy |
| RWEB-PROXY | d7 | 3056 | Reverse Web Proxy |
| FWEB-PROXY | d8 | 3057 | Forward Web Proxy |
| APP-SVR | ba | 3058 | Application Server |
| WEB-SVR | b9 | 3059 | Web Server |
| FMWR-SVR | bb | 3060 | Firmware Server |
| RCC-SVR | bc | 3061 | RCC Server |
| RCC-DCO | be | 3063 | RCC DCO |
| RCC-UNIX | bf | 3066 | RCC UNIX |
| PRINT-SVR | b0 | 3068 | Print Server |
| FILE-SVR | b1 | 3069 | File Server |
| ADM-DCO | a1 | 3163 | Admin DCO |

#### L2_Non-Stretched Template (2 BDs/EPGs)

| BD/EPG Name | Function Code | IPv6 VLAN | Description |
|-------------|---------------|-----------|-------------|
| DB-SVR | db | 3067 | Database Server |
| SYSLOG | sl | 3199 | Syslog |

#### Site-Specific Templates (2 BDs/EPGs)

| BD/EPG Name | Template | IPv6 VLAN | Description |
|-------------|----------|-----------|-------------|
| GEF-MGMT | Site1-Specific_Only | 3062 | GEF Management (Site G) |
| BACKUP-SVR | Site2-Specific_Only | 3070 | Backup Server (Site K) |

---

## Static Port Bindings

### Binding Logic

The `generate_ipv6_bindings3.py` script applies static port bindings based on IPv4 reference EPGs:

1. **Template Source**: Uses IPv4 EPG bindings as template for IPv6 EPGs
2. **Compute Leaf Mirroring**: 
   - Bindings on 101/102 → copied to both 101/102 AND 111/112
   - Bindings on 111/112 → copied to both 111/112 AND 101/102
3. **Border Leaf Isolation**:
   - Bindings on 101/102 → remain ONLY on 101/102 (no mirroring)

### VLAN Range

- **IPv6 VLANs**: 3001 - 3500

### Usage

```bash
# Generate bindings (copy file to remote server first)
mv generate_ipv6_bindings3.json generate_ipv6_bindings3.py
python3 generate_ipv6_bindings3.py

# Remove bindings
mv remove_all_rcc_bindings.json remove_all_rcc_bindings.py
python3 remove_all_rcc_bindings.py --dry-run    # Preview
python3 remove_all_rcc_bindings.py              # Execute
```

---

## L3Out Configuration

### NDO-Managed (l3outs_ndo.tf)

- L3Out definitions
- External EPGs with `::/0` subnet
- Contract associations (consumer/provider for `Any_VRF-RCC`)
- BD-to-L3Out associations for all 39 BDs

### APIC-Managed (l3outs_apic.tf.disabled)

After NDO deployment, enable this file to configure:

- Node profiles (nodes 101, 102)
- Interface profiles
- OSPF interface settings
- SVI path attachments: `PC_DC_FTD_A`, `PC_DC_FTD_B`

**Placeholder values to update:**
- APIC URLs
- Router IDs (10.66.x.x)
- IPv6 addresses (fd00:0:0:x::x/64)
- OSPF Area ID

---

## Deployment Order

### Phase 1: NDO Configuration

```bash
cd /Users/johbarbe/Documents/terraform_redesign_esg/NDO

# Initialize Terraform
terraform init

# Plan and review
terraform plan

# Apply NDO configuration
terraform apply
```

### Phase 2: APIC L3Out Configuration

1. Wait for NDO to push L3Outs to APIC
2. Rename: `l3outs_apic.tf.disabled` → `l3outs_apic.tf`
3. Uncomment resources (remove `#/*` and `#*/`)
4. Update placeholder values
5. Apply: `terraform apply`

### Phase 3: Static Port Bindings

```bash
# Copy script to server with NDO access
scp generate_ipv6_bindings3.json user@server:~/generate_ipv6_bindings3.py

# Run on server
python3 generate_ipv6_bindings3.py
```

---

## Environment Variables

The binding scripts support environment variables:

```bash
export NDO_HOST="198.18.133.100"
export NDO_USER="admin"
export NDO_PASSWORD="your_password"
```

---

## Verification

### Check Deployed Objects

```bash
# Terraform state
terraform state list | grep -E "bd_|epg_|l3out"

# NDO API (from script)
python3 check_rcc_bindings.py
```

### Backup Analysis

NDO backups can be analyzed:

```bash
cd NDO/backup_analysis
tar -xzf Backup-*.tar.gz
strings 20260203144943/backup | grep -E "BD-|EPG-|L3Out-RCC"
```

---

## File Naming Convention

Scripts are stored with `.json` extension to prevent accidental execution but are Python files:

| Stored As | Rename To |
|-----------|-----------|
| `generate_ipv6_bindings3.json` | `generate_ipv6_bindings3.py` |
| `remove_all_rcc_bindings.json` | `remove_all_rcc_bindings.py` |

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `ep_move_detection_mode` error | Remove attribute from TF state or use `lifecycle { ignore_changes }` |
| `staticport path must be unique` | Script checks for duplicates; remove existing bindings first |
| HTTP 400 on binding removal | Use batch REPLACE mode (current script version) |
| Missing reference EPG bindings | Check IPv4 EPG has bindings on target leaves |

### Binding Verification

```bash
# Check which leaves have bindings
python3 remove_all_rcc_bindings.py --dry-run --show-all
```

---

## Schema Structure

```
Schema: AFRICOM
├── UpgradeTemplate1
│   ├── VRF-RCC
│   └── Contract: Any_VRF-RCC
├── L2_Stretched
│   ├── BDs (35)
│   ├── EPGs (35) in AppProf-RCC
│   └── Site deployments (Site1, Site2)
├── L2_Non-Stretched
│   ├── BDs (2)
│   └── EPGs (2)
├── Site1-Specific_Only
│   ├── BD-GEF-MGMT
│   ├── EPG-GEF-MGMT
│   ├── L3Out-RCC-E-G
│   └── ExtEPG-RCC-E-G
└── Site2-Specific_Only
    ├── BD-BACKUP-SVR
    ├── EPG-BACKUP-SVR
    ├── L3Out-RCC-E-K
    └── ExtEPG-RCC-E-K
```

---

## Contact

For questions about this deployment, contact the network automation team.

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-03 | 1.0 | Initial deployment of IPv6 RCC infrastructure |

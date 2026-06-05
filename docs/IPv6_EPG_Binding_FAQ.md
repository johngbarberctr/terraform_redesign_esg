# IPv6 EPG Binding System - Frequently Asked Questions

## Overview

This document explains how the IPv6 EPG binding system works, including how mappings are determined, how VLANs are assigned, and how to make changes in the future.

---

## Q1: How are IPv6 EPGs mapped to IPv4 reference EPGs based on function?

**Answer:** The mapping is **MANUAL** and defined in the `epg_mapping` dictionary in `generate_ipv6_bindings3.py`.

### Example from the code:

```python
self.epg_mapping = {
    'EPG-NAC': {
        'reference': 'EPG-V0015',    # <-- Manual mapping to IPv4 EPG
        'vlan': 3021,
        'function': '15',
        'subnet': '1500::/56'
    },
    'EPG-ACAS-MGMT': {
        'reference': 'EPG-V0140',    # <-- Maps to ACAS Scanners
        'vlan': 3198,
        'function': 'c6',
        'subnet': 'c600::/56'
    },
    ...
}
```

### How the mapping was determined:

1. **Analyzed Service Categories** from the README (e.g., "Infrastructure Management", "Security Services")
2. **Matched IPv6 EPG purposes** to functionally similar IPv4 EPGs
3. **Example:** `EPG-ACAS-MGMT` (IPv6) → `EPG-V0140` (IPv4 ACAS Scanners) because they serve the same security function

### What the script does with the mapping:

1. Looks up the reference EPG (e.g., `EPG-V0015`) in NDO
2. Copies its port bindings (VPCs, paths)
3. Applies them to the IPv6 EPG with the new VLAN

---

## Q2: How are VLANs assigned based on function codes?

**Answer:** VLANs are also **MANUALLY** defined in the same `epg_mapping` dictionary.

### VLAN Sources:

| Source | Description |
|--------|-------------|
| **Verified VLANs** | From `IPv6_VMs.csv` (actual deployment data) |
| **Assigned VLANs** | From safe range (3050-3062) for function codes not in CSV |

### Example from the code:

```python
# Verified VLANs from actual VM deployment data
self.verified_vlans = [
    3001, 3021, 3064, 3065, 3083, 3102, 3105, 3163, 3173, 3175, 
    3192, 3195, 3197, 3198, 3208, 3209, 3210, 3213, 3217, 3219, 
    3221, 3224, 3228, 3230, 3236, 3442
]
```

---

## Q3: Since IPv4 EPGs aren't function-based, how is the mapping identified?

**Answer:** IPv4 EPGs use **VLAN-based naming** (EPG-V0015, EPG-V0216, etc.), not function codes. The mapping was determined through:

### Mapping Methods:

1. **Functional Equivalence** - Matching by purpose/service type
2. **README Documentation** - The IPv4 to IPv6 mapping table
3. **Manual Analysis** - Determining which IPv4 EPG serves the same network function

### Example Mapping Table (from README):

| IPv6 EPG | Maps to IPv4 | Purpose |
|----------|--------------|---------|
| EPG-NAC | EPG-V0015 | Network Access Control |
| EPG-CFG-MGMT | EPG-V0021 | Configuration Management |
| EPG-MECM | EPG-V0033 | Endpoint Management |
| EPG-ACAS-SCANNERS | EPG-V0140 | Vulnerability Scanners |
| EPG-AD | EPG-V0150 | Active Directory |
| EPG-RCC-SVR | EPG-V0470 | RCC Servers |

**This is why the script has a hardcoded mapping** - there's no automatic way to derive the relationship between function codes and VLAN-based IPv4 EPG names.

---

## Q4: Are you running separate instances for K and G sites?

### For NDO (vhost_mgmt.tf): **NO - Single Instance**

NDO manages both sites from one place using **template-based deployment**:

| Template | Deploys To |
|----------|------------|
| `Site1-Specific_Only` | Site G only (Grafenwoehr) |
| `Site2-Specific_Only` | Site K only (Kaiserslautern) |
| `L2_Stretched` | Both sites |

### For APIC (vhost_mgmt_apic.tf): **YES - Two Provider Instances**

```hcl
provider "aci" {
  alias = "apic_g"
  url   = "https://198.18.133.11"  # Site G APIC
}

provider "aci" {
  alias = "apic_k"
  url   = "https://198.18.133.12"  # Site K APIC
}
```

Each resource specifies which provider to use:
- `provider = aci.apic_g` for Site G resources
- `provider = aci.apic_k` for Site K resources

---

## Q5: How do I add more function codes or change EPGs/VLANs in the future?

### Adding a New Function Code

**Step 1:** Add BD and EPG to Terraform (bds_epgs.tf or new .tf file):

```hcl
# Bridge Domain
resource "mso_schema_template_bd" "bd_new_service" {
  schema_id         = data.mso_schema.existing.id
  template_name     = "L2_Stretched"
  name              = "BD-NEW-SERVICE"
  display_name      = "BD-NEW-SERVICE"
  vrf_name          = mso_schema_template_vrf.vrf_rcc.name
  vrf_schema_id     = data.mso_schema.existing.id
  vrf_template_name = "VRF_Template"
  # ... other BD settings
}

# Subnet
resource "mso_schema_template_bd_subnet" "bd_new_service_subnet" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  bd_name       = mso_schema_template_bd.bd_new_service.name
  ip            = "XX00::1/56"  # Based on function code
  scope         = "public"
  shared        = false
}

# EPG
resource "mso_schema_template_anp_epg" "epg_new_service" {
  schema_id     = data.mso_schema.existing.id
  template_name = "L2_Stretched"
  anp_name      = mso_schema_template_anp.appprof_rcc_stretched.name
  name          = "EPG-NEW-SERVICE"
  display_name  = "EPG-NEW-SERVICE"
  bd_name       = mso_schema_template_bd.bd_new_service.name
}
```

**Step 2:** Add to `generate_ipv6_bindings3.py`:

```python
self.epg_mapping = {
    # ... existing mappings ...
    
    'EPG-NEW-SERVICE': {
        'reference': 'EPG-V0XXX',  # Pick appropriate IPv4 reference EPG
        'vlan': 3XXX,              # Assign VLAN
        'template': 'L2_Stretched',
        'function': 'XX',          # Function code (hex)
        'subnet': 'XX00::/56'
    },
}

# Also add VLAN to verified list if confirmed
self.verified_vlans = [..., 3XXX]
```

**Step 3:** Deploy:

```bash
# Deploy to NDO
terraform apply

# Create port bindings
python3 generate_ipv6_bindings3.py deploy
```

---

### Changing a VLAN Assignment

1. Update `vlan` value in `epg_mapping` dictionary in `generate_ipv6_bindings3.py`
2. Update `verified_vlans` list if needed
3. Re-run the Python script:

```bash
python3 generate_ipv6_bindings3.py deploy
```

---

### Changing a Reference EPG

1. Update `reference` value in `epg_mapping` dictionary
2. Re-run the Python script (it will copy bindings from the new reference EPG):

```bash
python3 generate_ipv6_bindings3.py deploy
```

---

### Changing an EPG Name

1. Update the EPG name in the Terraform file
2. Update the key in `epg_mapping` dictionary
3. Run both:

```bash
terraform apply
python3 generate_ipv6_bindings3.py deploy
```

---

## Quick Reference Summary

| Task | Files to Modify | Commands |
|------|-----------------|----------|
| Add new function code | `.tf` file + `generate_ipv6_bindings3.py` | `terraform apply` then `python3 generate_ipv6_bindings3.py deploy` |
| Change VLAN | `generate_ipv6_bindings3.py` | `python3 generate_ipv6_bindings3.py deploy` |
| Change reference EPG | `generate_ipv6_bindings3.py` | `python3 generate_ipv6_bindings3.py deploy` |
| Change EPG name | `.tf` file + `generate_ipv6_bindings3.py` | `terraform apply` then `python3 generate_ipv6_bindings3.py deploy` |

---

## File Locations

| File | Purpose |
|------|---------|
| `bds_epgs.tf` | Main Terraform config for BDs and EPGs |
| `vhost_mgmt.tf` | Function code 66 NDO configuration |
| `vhost_mgmt_apic.tf` | APIC-specific L3Out/OSPF configuration |
| `generate_ipv6_bindings3.py` | Python script for port bindings |
| `IPv6_VMs.csv` | Source of truth for VLANs |
| `README.md` | Documentation with mapping tables |

---

*Document generated: January 2026*

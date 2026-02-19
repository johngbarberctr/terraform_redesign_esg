# Terraform Deployment Guide - RCC IPv6 Infrastructure

## Overview

This setup deploys IPv6 Bridge Domains, EPGs, L3Outs, and External EPGs to NDO (Nexus Dashboard Orchestrator) for a multi-site ACI fabric.

### Files

| File | Purpose |
|------|---------|
| `bds_epgs.tf` | BDs, Subnets, EPGs, VRF, Contracts, Site associations |
| `l3outs_ndo.tf` | L3Outs, External EPGs, BD-to-L3Out associations |
| `l3outs_apic.tf.disabled` | APIC-specific config (OSPF, Node profiles, SVIs) - **Enable after NDO deploy** |
| `generate_ipv6_bindings3.py` | Python script for EPG static port bindings |

---

## Deployment (terraform apply)

### Phase 1: Deploy NDO Configuration

```bash
cd /Users/johbarbe/Documents/terraform_redesign_esg/NDO

# Initialize Terraform (first time or after provider changes)
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply
```

This creates:
- VRF-RCC with vzAny contracts
- 35 Bridge Domains with IPv6 subnets
- 35 EPGs with domain associations
- L3Out-RCC-E-G (Site G) and L3Out-RCC-E-K (Site K)
- External EPGs for each site
- BD-to-L3Out associations

### Phase 2: Deploy from NDO UI

1. Log into NDO
2. Go to **Application Management** → **Schemas** → **AEDCE**
3. Click **Deploy to Sites**
4. Select both sites (APIC1, APIC2)
5. Click **Deploy**

### Phase 3: Add EPG Port Bindings (Python Script)

```bash
# Test first with dry-run
python3 generate_ipv6_bindings3.py --dry-run

# Deploy bindings
python3 generate_ipv6_bindings3.py
```

Then deploy from NDO UI again to push port bindings to APICs.

### Phase 4: Enable APIC Configuration (Optional)

Only after NDO has deployed L3Outs to APICs:

```bash
# Rename to enable the file
mv l3outs_apic.tf.disabled l3outs_apic.tf

# Edit l3outs_apic.tf - uncomment the resource blocks (remove /* and */)

# Apply APIC configuration
terraform apply
```

This adds:
- OSPF configuration
- Node profiles
- Interface profiles
- SVI path attachments

---

## Destruction (terraform destroy)

### Option A: Destroy Everything

```bash
cd /Users/johbarbe/Documents/terraform_redesign_esg/NDO

# If l3outs_apic.tf is enabled, destroy APIC resources first
# (Comment out or rename l3outs_apic.tf back to .disabled)
mv l3outs_apic.tf l3outs_apic.tf.disabled

# Destroy all NDO resources
terraform destroy
```

**Important**: After terraform destroy, you must also **Undeploy** from NDO UI:
1. Go to **Application Management** → **Schemas** → **AEDCE**
2. Click **Undeploy from Sites**

### Option B: Destroy Only L3Out/External EPG Resources

If you only want to remove L3Outs while keeping BDs/EPGs:

```bash
# Destroy specific resources
terraform destroy -target=mso_schema_template_l3out.l3out_rcc_e_g
terraform destroy -target=mso_schema_template_l3out.l3out_rcc_e_k
terraform destroy -target=mso_schema_template_external_epg.ext_epg_rcc_e_g
terraform destroy -target=mso_schema_template_external_epg.ext_epg_rcc_e_k
```

### Option C: Complete Fresh Start

If things get out of sync:

```bash
# 1. Undeploy from NDO UI first

# 2. Delete Terraform state
rm terraform.tfstate terraform.tfstate.backup

# 3. Manually delete resources from NDO UI if needed

# 4. Re-initialize and apply
terraform init
terraform apply
```

---

## Common Issues & Solutions

### "Duplicate Resource" Error
**Cause**: Resource already exists in NDO
**Fix**: Delete the resource from NDO UI, then run terraform apply

### "Must have unique contracts" Error
**Cause**: Contract already assigned in NDO
**Fix**: Remove contract from VRF vzAny or External EPG in NDO UI

### "L3Out must be deployed before ExternalEPG" Error
**Cause**: External EPG references L3Out that isn't associated with the site
**Fix**: Ensure L3Outs use unique names per site (L3Out-RCC-E-G, L3Out-RCC-E-K)

### NDO Deploy Button Grayed Out
**Cause**: Template not associated with site, or validation errors
**Fix**: Check schema for errors, verify template-to-site associations

### State Sync Issues
**Cause**: Manual changes in NDO not reflected in Terraform state
**Fix**: Either:
- Remove from NDO and let Terraform recreate, OR
- Import into state: `terraform import <resource_type>.<name> <id>`

---

## Resource Naming Convention

| Resource Type | Site G | Site K |
|--------------|--------|--------|
| L3Out | L3Out-RCC-E-G | L3Out-RCC-E-K |
| External EPG | ExtEPG-RCC-E-G | ExtEPG-RCC-E-K |
| BDs | BD-{NAME} | BD-{NAME} |
| EPGs | EPG-{NAME} | EPG-{NAME} |

---

## Quick Reference Commands

```bash
# Initialize
terraform init

# Preview changes
terraform plan

# Apply all
terraform apply

# Apply with auto-approve (skip confirmation)
terraform apply -auto-approve

# Destroy all
terraform destroy

# Destroy specific resource
terraform destroy -target=<resource_type>.<resource_name>

# Show current state
terraform show

# List resources in state
terraform state list

# Remove resource from state (without destroying)
terraform state rm <resource_type>.<resource_name>

# Import existing resource
terraform import <resource_type>.<resource_name> <resource_id>

# Refresh state from remote
terraform refresh
```

---

## Environment Variables

Set these for credentials (optional - can also use terraform.tfvars):

```bash
export TF_VAR_ndo_username="admin"
export TF_VAR_ndo_password="your_password"
export TF_VAR_apic_username="admin"
export TF_VAR_apic_password="your_password"
```

---

## File Management

| Action | Command |
|--------|---------|
| Enable APIC config | `mv l3outs_apic.tf.disabled l3outs_apic.tf` |
| Disable APIC config | `mv l3outs_apic.tf l3outs_apic.tf.disabled` |
| Backup state | `cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)` |

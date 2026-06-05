# ACI Automation Master Reference Guide

> **Quick Reference:** This document provides a complete map of all ACI automation tools, organized by environment (LAB vs PRODUCTION) and capability.

---

## ENVIRONMENT REFERENCE

| Environment | NDO Host | APIC Site G | APIC Site K | Username | Password |
|-------------|----------|-------------|-------------|----------|----------|
| **LAB** | 198.18.133.100 | 198.18.133.11 | 198.18.133.12 | admin | C1sco12345 |
| **PRODUCTION** | 155.155.32.30 | 155.155.32.20 | 155.155.33.20 | svc.rcc.nmd.dc | (vault) |

### Servers

| Server | IP | Environment | Purpose |
|--------|-----|-------------|---------|
| Local Mac | - | LAB | Development, testing |
| Snake | - | PRODUCTION | N5K migration, ACI leaf replacement |
| Terraform Server | 136.215.4.96 | PRODUCTION | IPv6 RCC NAC deployment |

---

## QUICK NAVIGATION

### By Task - What Do You Want To Do?

| Task | LAB Location | PRODUCTION Location |
|------|--------------|---------------------|
| **Setup baseline ACI fabric** | `Snake/LAB/N5K/` | `Snake/PRODUCTION/N5K/` |
| **Migrate from N5K switches** | `Snake/LAB/N5K/` | `Snake/PRODUCTION/N5K/` |
| **Replace ACI leaf switches** | `Snake/LAB/aci-lf-rplc/` | `Snake/PRODUCTION/aci-lf-rplc/` |
| **Deploy IPv6 RCC infrastructure** | `ndo-terraform/` | `ndo_terraform_nac/136.215.4.96/` |
| **Deploy IPv4 fabric + bindings** | `ndo_terraform/` | N/A |
| **Deploy IPv4 NAC module (266 EPGs)** | `ndo_terraform_nac/` | N/A |

---

## CAPABILITY MATRIX

### 1. ACI Fabric Baseline Setup

Creates baseline ACI fabric configuration: templates, node profiles, interfaces, port-channels.

| File | Purpose | LAB | PRODUCTION |
|------|---------|-----|------------|
| `setup_fabric_policies_africom.yml` | Create fabric templates, node profiles, interfaces | ✅ | ✅ |

**Usage:**
```bash
# Activate virtual environment first
source ~/dc_redesign/bin/activate  # Mac
source /home/john.g.barber.ctr/ansvenv/bin/activate  # Snake

# Run playbook
ansible-playbook setup_fabric_policies_africom.yml
```

---

### 2. N5K Data Gathering (Migration)

Gather interface, VLAN, and port-channel data from legacy Nexus 5K switches.

| File | Purpose | LAB | PRODUCTION |
|------|---------|-----|------------|
| `get_active_ports.yml` | Gather connected interfaces | ✅ | ✅ |
| `get_active_pc_ports5.yml` | Gather port-channel data | ✅ | ✅ |
| `sh_vl_summ2.yml` | Gather VLAN information | ✅ | ✅ |

**Usage:**
```bash
ansible-playbook get_active_ports.yml
ansible-playbook get_active_pc_ports5.yml
ansible-playbook sh_vl_summ2.yml
```

---

### 3. Data Processing

Process gathered data and generate configuration files.

| File | Purpose | LAB | PRODUCTION |
|------|---------|-----|------------|
| `process_data.yml` | Process N5K data → terraform.tfvars.json | ✅ | ✅ |
| `process_data_LF.yml` | Process APIC export → terraform.tfvars.json | ✅ | ✅ |
| `merge_tfvars.py` | Merge site configs | ✅ | ✅ |

**Usage:**
```bash
# N5K Migration
ansible-playbook process_data.yml -e site=Site1
mv terraform.tfvars.json terraform.site1.json
ansible-playbook process_data.yml -e site=Site2
mv terraform.tfvars.json terraform.site2.json
python merge_tfvars.py terraform.site1.json terraform.site2.json terraform.tfvars.json

# Leaf Replacement
ansible-playbook process_data_LF.yml
```

---

### 4. NDO Binding Deployment

Deploy static port bindings to NDO EPGs.

| File | Purpose | LAB | PRODUCTION |
|------|---------|-----|------------|
| `deploy_bindings_python_v2.py` | Deploy bindings (N5K workflow) | ✅ | ✅ |
| `deploy_bindings_python.py` | Deploy bindings (Leaf replacement) | ✅ | ✅ |

**Usage:**
```bash
# Dry run first
python deploy_bindings_python_v2.py terraform.tfvars.json AFRICOM --dry-run

# Deploy
python deploy_bindings_python_v2.py terraform.tfvars.json AFRICOM
```

---

### 5. NDO Binding Removal

Remove specific static port bindings from NDO.

| File | Purpose | LAB | PRODUCTION |
|------|---------|-----|------------|
| `selective_bindings_del.py` | Remove specific bindings | ✅ | ✅ |

**Usage:**
```bash
# Dry run first
python selective_bindings_del.py bindings_to_remove.json --dry-run

# Remove
python selective_bindings_del.py bindings_to_remove.json AFRICOM
```

---

### 6. IPv6 RCC Infrastructure (Terraform)

Deploy IPv6 RCC infrastructure: VRF, BDs, EPGs, L3Outs, bindings.

| File | Purpose | LAB | PRODUCTION |
|------|---------|-----|------------|
| `main.tf` | Terraform provider config | ✅ | ✅ |
| `variables.tf` | Variable definitions | ✅ | ✅ |
| `terraform.tfvars` | Variable values (IPs, credentials) | ✅ | ✅ |
| `bds_epgs.tf` | VRF, 37 BDs, 37 EPGs, subnets | ✅ | ✅ |
| `l3outs_ndo.tf` | NDO L3Out configuration | ✅ | ✅ |
| `l3outs_apic.tf` | APIC L3Out details (node/interface profiles) | ✅ | ✅ |
| `generate_ipv6_bindings3.py` | Generate/deploy IPv6 port bindings | ✅ | ✅ |

**Usage:**
```bash
# Initialize
terraform init

# Plan & Apply
terraform plan
terraform apply

# Deploy bindings
python3 generate_ipv6_bindings3.py dry-run
python3 generate_ipv6_bindings3.py deploy
```

---

### 7. IPv4 LAB Fabric & Binding Deployment - `~/ndo_terraform/`

Deploy IPv4 fabric policies and static port bindings to NDO in the LAB environment.
Uses Ansible playbooks and Python REST API scripts.

**Key Characteristics:**
- Ansible + Python REST API approach (not Terraform)
- Creates fabric templates, node profiles, interfaces, port-channels
- Deploys/removes static port bindings to NDO EPGs
- Credentials managed via Ansible Vault

| File | Purpose |
|------|---------|
| `setup_fabric_policies_africom.yml` | Create fabric resource templates, interface policy groups, node profiles, physical interfaces, port-channels |
| `deploy_bindings_python_v2.py` | Deploy static port bindings to NDO EPGs via REST API (supports `--dry-run`) |
| `selective_bindings_del.py` | Remove specific static port bindings from NDO EPGs |
| `ansible.cfg` | Ansible configuration (vault password file reference) |
| `vault.yml` | NDO password, encrypted with Ansible Vault |
| `vault_pass.txt` | Password to decrypt vault.yml (**do not commit**) |
| `.gitignore` | Git ignore rules |
| `README.md` | Directory-specific documentation |

**Usage:**
```bash
source ~/dc_redesign/bin/activate

# Step 1: Setup fabric (first time only)
ansible-playbook setup_fabric_policies_africom.yml

# Step 2: Deploy bindings
python deploy_bindings_python_v2.py terraform.tfvars.json AFRICOM --dry-run
python deploy_bindings_python_v2.py terraform.tfvars.json AFRICOM

# Remove specific bindings
python selective_bindings_del.py bindings_to_remove.json --dry-run
python selective_bindings_del.py bindings_to_remove.json AFRICOM
```

---

### 8. IPv4 NAC Terraform Module - `~/ndo_terraform_nac/`

> **NOTE:** This was previously at `~/ndo_terraform/` and has been moved to `~/ndo_terraform_nac/` to separate it from the LAB deployment tools above.

Deploy complete IPv4 infrastructure using the `netascode/nac-ndo` Terraform module.
Configuration is defined in **YAML files**, not `.tf` files.
Includes GitLab CI/CD pipeline, test suite, and schema definitions.

**Key Characteristics:**
- Uses `netascode/nac-ndo/mso` module (version 1.2.0)
- Configuration in YAML: `data/ndo/*.nac.yaml`
- Manages: system, sites, tenants, schemas, templates
- Contains 266 EPGs, 532 BDs for AFRICOM schema
- Has its own git repo and GitLab CI/CD pipeline

| File/Directory | Purpose |
|----------------|---------|
| `main.tf` | NAC module config |
| `data/ndo/schema_AFRICOM.nac.yaml` | Schema, EPGs, BDs (YAML) |
| `data/ndo/ndo.nac.yaml` | Sites, tenants (YAML) |
| `.env` | LAB MSO credentials |
| `.gitlab-ci.yml`, `.ci/` | GitLab CI/CD pipeline |
| `tests/`, `scripts/` | Test suite and utilities |
| `schemas/` | APIC and NDO schema definitions |
| `136.215.4.96/` | PRODUCTION IPv6 RCC (Direct Terraform) |

**Usage:**
```bash
# Set environment variables
export MSO_USERNAME="admin"
export MSO_PASSWORD="C1sco12345"
export MSO_URL="https://198.18.133.100"

terraform init
terraform plan
terraform apply -parallelism=1
```

---

### 9. IPv6 RCC Infrastructure - `ndo-terraform/`

> **IMPORTANT:** `ndo-terraform/` (with hyphen) uses **Direct Terraform Resources**

Deploy IPv6 RCC infrastructure using direct Terraform resources (not NAC module).
Configuration is defined in **`.tf` files** with explicit resource definitions.

**Key Characteristics:**
- Uses direct `mso_*` and `aci_*` Terraform resources
- Configuration in `.tf` files: `bds_epgs.tf`, `l3outs_ndo.tf`, etc.
- More granular control over individual resources
- Contains 37 BDs, 37 EPGs for IPv6 RCC

| File | Purpose | LAB | PRODUCTION |
|------|---------|-----|------------|
| `main.tf` | Provider config (direct) | ✅ ndo-terraform | ✅ 136.215.4.96 |
| `variables.tf` | Variable definitions | ✅ ndo-terraform | ✅ 136.215.4.96 |
| `terraform.tfvars` | Variable values | ✅ ndo-terraform | ✅ 136.215.4.96 |
| `bds_epgs.tf` | VRF, 37 BDs, 37 EPGs | ✅ ndo-terraform | ✅ 136.215.4.96 |
| `l3outs_ndo.tf` | L3Out config | ✅ ndo-terraform | ✅ 136.215.4.96 |
| `l3outs_apic.tf` | APIC L3Out details | ✅ ndo-terraform | ✅ 136.215.4.96 |
| `generate_ipv6_bindings3.py` | Deploy IPv6 bindings | ✅ ndo-terraform | ✅ 136.215.4.96 |

**Usage:**
```bash
# Set environment variables
export MSO_USERNAME="svc.rcc.nmd.dc"
export MSO_PASSWORD="<password>"
export MSO_URL="https://155.155.32.30"

terraform init
terraform plan
terraform apply

# Deploy bindings
python3 generate_ipv6_bindings3.py dry-run
python3 generate_ipv6_bindings3.py deploy
```

---

## DIRECTORY MAP

```
~/
├── Documents/terraform_redesign_esg/          ← WORKSPACE ROOT
│   ├── ACI_LAB.code-workspace                 ← Opens LAB workspace (3 folders)
│   ├── ACI_PRODUCTION.code-workspace          ← Opens PRODUCTION workspace (2 folders)
│   ├── ACI_MASTER_README.md                   ← THIS FILE
│   │
│   └── ndo-terraform/                         ← LAB IPv6 RCC (Direct TF Resources)
│       ├── main.tf                               37 BDs, 37 EPGs
│       ├── variables.tf                          198.18.X.X IPs
│       ├── terraform.tfvars
│       ├── bds_epgs.tf
│       ├── l3outs_ndo.tf
│       ├── l3outs_apic.tf.disabled
│       └── generate_ipv6_bindings3.py
│
├── Documents/terraform_redesign/n5k_replacement/
│   └── Snake/
│       ├── PRODUCTION/                        ← Run on Snake server (155.155.X.X)
│       │   ├── N5K/                           ← N5K Migration & Fabric Setup
│       │   │   ├── setup_fabric_policies_africom.yml
│       │   │   ├── process_data.yml
│       │   │   ├── deploy_bindings_python_v2.py
│       │   │   ├── selective_bindings_del.py
│       │   │   ├── merge_tfvars.py
│       │   │   ├── get_active_ports.yml
│       │   │   ├── get_active_pc_ports5.yml
│       │   │   ├── sh_vl_summ2.yml
│       │   │   ├── vault.yml                  ← NDO password (encrypted)
│       │   │   ├── secrets.yml                ← Switch credentials (encrypted)
│       │   │   └── vault_pass.txt             ← Vault password
│       │   │
│       │   └── aci-lf-rplc/                   ← ACI Leaf Replacement
│       │       ├── process_data_LF.yml
│       │       ├── deploy_bindings_python.py
│       │       ├── selective_bindings_del.py
│       │       ├── vault.yml
│       │       └── .vault_pass
│       │
│       └── LAB/                               ← Run on Local Mac (198.18.X.X)
│           ├── N5K/                           ← Same capabilities as PRODUCTION
│           └── aci-lf-rplc/                   ← Same capabilities as PRODUCTION
│
├── ndo_terraform/                             ← LAB IPv4 Fabric & Binding Deployment
│   ├── setup_fabric_policies_africom.yml           Ansible + Python REST API
│   ├── deploy_bindings_python_v2.py              Deploy bindings to NDO
│   ├── selective_bindings_del.py                 Remove bindings from NDO
│   ├── ansible.cfg                               Ansible configuration
│   ├── vault.yml                                 NDO password (encrypted)
│   ├── vault_pass.txt                            Vault password
│   ├── .gitignore
│   └── README.md
│
└── ndo_terraform_nac/                         ← IPv4 NAC Terraform Module + GitLab CI
    │                                             netascode/nac-ndo module
    │                                             266 EPGs, 532 BDs
    │                                             Has its own git repo
    │
    ├── main.tf                                ← NAC module config
    ├── .env                                   ← LAB MSO credentials
    ├── data/ndo/schema_AFRICOM.nac.yaml         ← 266 EPGs, 532 BDs (YAML)
    ├── data/ndo/ndo.nac.yaml                  ← Sites, tenants (YAML)
    ├── .gitlab-ci.yml, .ci/                   ← GitLab CI/CD pipeline
    ├── tests/, scripts/                       ← Test suite and utilities
    ├── schemas/                               ← APIC and NDO schema definitions
    │
    └── 136.215.4.96/                          ← PRODUCTION IPv6 RCC (Direct TF)
        ├── main.tf                               155.155.X.X IPs
        ├── variables.tf
        ├── terraform.tfvars
        ├── bds_epgs.tf
        ├── l3outs_ndo.tf
        ├── l3outs_apic.tf
        └── generate_ipv6_bindings3.py
```

### Workspace Structure

**ACI_LAB.code-workspace** (3 folders):

| Folder Name | Path | Purpose |
|-------------|------|---------|
| LAB - IPv6 RCC (ndo-terraform) | `ndo-terraform/` | IPv6 RCC via direct Terraform |
| LAB - IPv4 NAC (ndo_terraform) | `~/ndo_terraform/` | IPv4 fabric setup + binding deployment |
| LAB - N5K Migration & Leaf Replacement | `Snake/LAB/` | Data gathering, processing, leaf replacement |

**ACI_PRODUCTION.code-workspace** (2 folders):

| Folder Name | Path | Purpose |
|-------------|------|---------|
| PROD - IPv6 RCC (136.215.4.96) | `~/ndo_terraform_nac/136.215.4.96/` | IPv6 RCC production deployment |
| PROD - N5K Migration & Leaf Replacement | `Snake/PRODUCTION/` | Production N5K migration |

### Quick Reference: Directory Names

| Directory | Purpose | Approach |
|-----------|---------|----------|
| `~/ndo_terraform/` | LAB IPv4 fabric & binding deployment | Ansible + Python REST API |
| `~/ndo_terraform_nac/` | IPv4 NAC module (266 EPGs) + GitLab CI | Terraform NAC module (YAML) |
| `ndo-terraform/` | LAB IPv6 RCC (37 EPGs) | Direct Terraform resources (.tf) |
| `~/ndo_terraform_nac/136.215.4.96/` | PROD IPv6 RCC (37 EPGs) | Direct Terraform resources (.tf) |

---

## WORKFLOW GUIDES

### Workflow 1: N5K Switch Migration (PRODUCTION)

```
1. SSH to Snake server
2. cd ~/Snake/PRODUCTION/N5K/
3. Activate venv: source /home/john.g.barber.ctr/ansvenv/bin/activate
4. Gather data from N5K switches:
   - ansible-playbook get_active_ports.yml
   - ansible-playbook get_active_pc_ports5.yml
   - ansible-playbook sh_vl_summ2.yml
5. Process data for each site:
   - ansible-playbook process_data.yml -e site=Site1
   - mv terraform.tfvars.json terraform.site1.json
   - ansible-playbook process_data.yml -e site=Site2
   - mv terraform.tfvars.json terraform.site2.json
6. Merge configs:
   - python merge_tfvars.py terraform.site1.json terraform.site2.json terraform.tfvars.json
7. Setup fabric (first time only):
   - ansible-playbook setup_fabric_policies_africom.yml
8. Deploy bindings:
   - python deploy_bindings_python_v2.py terraform.tfvars.json AFRICOM --dry-run
   - python deploy_bindings_python_v2.py terraform.tfvars.json AFRICOM
```

### Workflow 2: ACI Leaf Replacement (PRODUCTION)

```
1. SSH to Snake server
2. cd ~/Snake/PRODUCTION/aci-lf-rplc/
3. Activate venv: source /home/john.g.barber.ctr/ansvenv/bin/activate
4. Export EPG data from APIC (see README in directory)
5. Process data:
   - ansible-playbook process_data_LF.yml
6. Deploy bindings:
   - python deploy_bindings_python.py terraform.tfvars.json --dry-run
   - python deploy_bindings_python.py terraform.tfvars.json
```

### Workflow 3: IPv6 RCC Deployment (PRODUCTION)

```
1. SSH to 136.215.4.96 (Terraform server)
2. cd ~/terraform_redesign_ipv6/  (or wherever files are deployed)
3. Activate venv: source ~/terraform/bin/activate
4. Set environment variables:
   - export MSO_USERNAME="svc.rcc.nmd.dc"
   - export MSO_PASSWORD="<password>"
   - export MSO_URL="https://155.155.32.30"
5. Deploy infrastructure:
   - terraform init
   - terraform plan
   - terraform apply
6. Deploy bindings:
   - python3 generate_ipv6_bindings3.py dry-run
   - python3 generate_ipv6_bindings3.py deploy
```

---

## CREDENTIALS MANAGEMENT

### Ansible Vault (Snake directories)

```bash
# View encrypted file
ansible-vault view --vault-password-file vault_pass.txt vault.yml

# Edit encrypted file
ansible-vault edit --vault-password-file vault_pass.txt vault.yml

# Create new vault
echo 'ndo_password: "your_password"' > vault.yml
ansible-vault encrypt --vault-password-file vault_pass.txt vault.yml
```

### Terraform Variables

```bash
# Set via environment variables
export MSO_USERNAME="admin"
export MSO_PASSWORD="C1sco12345"
export MSO_URL="https://198.18.133.100"

# Or use terraform.tfvars file
```

---

## TROUBLESHOOTING

### "ansible: command not found"
```bash
source ~/dc_redesign/bin/activate  # Mac
source /home/john.g.barber.ctr/ansvenv/bin/activate  # Snake
```

### "vault password not found"
```bash
ls -la vault_pass.txt .vault_pass
chmod 600 vault_pass.txt
```

### "Authentication failed" (NDO/APIC)
- Verify IP addresses match environment (LAB vs PRODUCTION)
- Check credentials in vault files
- Verify network connectivity

### "Schema not found"
- Confirm schema name is "AFRICOM"
- Verify NDO connection

---

## VERSION HISTORY

| Date | Change |
|------|--------|
| 2026-01-23 | Initial master README created |
| | Organized LAB/PRODUCTION parity |
| | Added selective_bindings_del.py to N5K toolkit |
| 2026-02-18 | Reorganized `~/ndo_terraform/` directory |
| | Moved NAC Terraform module + GitLab CI to `~/ndo_terraform_nac/` |
| | `~/ndo_terraform/` now contains only LAB IPv4 deployment tools (8 files) |
| | Updated ACI_LAB and ACI_PRODUCTION workspace paths |
| | Added workspace structure documentation |

---

## ARCHIVE (Redundant/Old Directories)

The following directories contain older versions and should not be used:

| Directory | Status |
|-----------|--------|
| `terraform_redesign/rcc-e_fabric/` | Archived - older version |
| `terraform_redesign/rcc-e_fabric_streamlined/` | Archived - older version |
| `terraform_redesign/static_bindings_optimization/` | Archived - older scripts |
| `terraform_redesign/older_stuff/` | Already archived |

---

*Last Updated: February 18, 2026*

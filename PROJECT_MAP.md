# Master Reference — ACI / NXOS Infrastructure as Code

Everything in one place. Saved at: `/Users/johbarbe/DC/ACI/terraform-esg/PROJECT_MAP.md`

---

## Servers

| Server | Hostname | Purpose |
|--------|----------|---------|
| Mac (local) | your laptop | Development, editing code |
| RHEL 8 (GitLab + projects) | the RHEL server | GitLab instance, project repos |
| Runner host | `apckw059aau0096` | Runs CI/CD jobs (shell executor) |
| NDO (LAB) | `198.18.133.100` | Cisco NDO — LAB environment |

---

## GitLab Projects (on RHEL server)

| Project | GitLab URL | RHEL Path | What it does |
|---------|-----------|-----------|-------------|
| terraform_redesign_esg | `web.git.mil/root/terraform_redesign_esg` | — | NDO Terraform (IPv6/ESG) + ACI Redesign |
| ndo_terraform | `web.git.mil/root/ndo_terraform` | — | NAC-based Terraform for NDO |
| n5k_replacement | `web.git.mil/root/n5k_replacement` | `~/nxos/n5k/` | N5K snake bindings (Python + Ansible) |
| aci-lf-rplc | (new project on web.git.mil) | `~/aci-lf-rplc/` | Leaf replacement bindings (Python + Ansible) |

---

## Mac — File Locations

### Workspaces

| Workspace file | Where it is |
|---------------|------------|
| ACI_LAB | `/Users/johbarbe/DC/ACI/terraform-esg/ACI_LAB.code-workspace` |
| ACI_PRODUCTION | `/Users/johbarbe/DC/ACI/terraform-esg/ACI_PRODUCTION.code-workspace` |

### ACI_LAB workspace folders

| Folder name in Cursor | Mac path |
|-----------------------|---------|
| LAB - ESG Terraform | `/Users/johbarbe/DC/ACI/terraform-esg/` |
| LAB - IPv4 NAC | `/Users/johbarbe/DC/ACI/ndo-terraform/` |
| LAB - IPv4 NAC Terraform | `/Users/johbarbe/DC/ACI/ndo-terraform-nac/` |
| LAB - IPv4 NAC Terraform (PROD) | `/Users/johbarbe/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/` |
| LAB - N5K Migration & Leaf Replacement | `/Users/johbarbe/DC/NXOS/n5k/` |
| LAB - ACI Leaf Replacement | `/Users/johbarbe/DC/NXOS/n5k/Snake/PRODUCTION/aci-lf-rplc/` |

### ACI_PRODUCTION workspace folders

| Folder name in Cursor | Mac path |
|-----------------------|---------|
| PROD - IPv6 RCC (136.215.4.96) | `/Users/johbarbe/DC/ACI/ndo-terraform-nac/136.215.4.96/` |
| PROD - N5K Migration & Leaf Replacement | `/Users/johbarbe/DC/NXOS/n5k/Snake/PRODUCTION/` |

### Where are the .gitlab-ci.yml files on Mac?

| Project | Mac path |
|---------|---------|
| terraform_redesign_esg | `/Users/johbarbe/DC/ACI/terraform-esg/.gitlab-ci.yml` |
| n5k (RHEL version) | `/Users/johbarbe/DC/NXOS/n5k/.gitlab-ci.yml` |
| aci-lf-rplc (RHEL version) | `/Users/johbarbe/DC/NXOS/n5k/Snake/LAB/aci-lf-rplc/.gitlab-ci.yml` |

---

## RHEL Server — File Locations

### aci-lf-rplc project (`~/aci-lf-rplc/`)

```
~/aci-lf-rplc/
├── .gitlab-ci.yml              ← CI pipeline
├── .gitignore
├── ansible.cfg
├── deploy_bindings_python.py   ← deploys bindings to NDO
├── selective_bindings_del.py   ← removes bindings from NDO
├── process_data_LF.yml         ← generates terraform.tfvars.json from epg_data.json
├── epg_data.json               ← INPUT: ACI EPG export
├── vault.yml                   ← encrypted NDO password (gitignored)
└── .vault_pass                 ← vault password file (gitignored)
```

### n5k project (`~/nxos/n5k/`)

```
~/nxos/n5k/
├── .gitlab-ci.yml              ← CI pipeline
├── deploy_bindings_python_v2.py ← deploys bindings to NDO (v2, PC/VPC)
├── selective_bindings_del.py    ← removes bindings from NDO
├── process_data.yml             ← generates terraform.tfvars.json from switch data
├── get_active_ports.yml         ← gathers port info from NX-OS switches
├── get_active_pc_ports5.yml     ← gathers port-channel info from NX-OS switches
├── setup_fabric_policies_africom.yml ← configures ACI fabric policies
├── merge_tfvars.py              ← merges multiple tfvars JSON files
├── ansible.cfg
├── inventory.ini
├── switch_interfaces.txt                      ← INPUT: from NX-OS
├── nxos_vlan_brief_formatted.txt              ← INPUT: from NX-OS
├── nxos_multiline_active_su_port_channels.txt ← INPUT: from NX-OS
├── vault.yml                    ← encrypted NDO password (gitignored)
└── vault_pass.txt               ← vault password file (gitignored)
```

---

## Copying files from Mac to RHEL server

Only these 2 files need to be copied:

| Mac path | RHEL destination |
|----------|-----------------|
| `/Users/johbarbe/DC/NXOS/n5k/Snake/LAB/aci-lf-rplc/.gitlab-ci.yml` | `~/aci-lf-rplc/.gitlab-ci.yml` |
| `/Users/johbarbe/DC/NXOS/n5k/.gitlab-ci.yml` | `~/nxos/n5k/.gitlab-ci.yml` |

---

## CI/CD Pipelines

### Pipeline flow (same for both projects)

```
validate → process-data → dry-run → deploy
                                       ↓
                                    remove (manual)
```

- **validate**: checks Python syntax
- **process-data**: runs Ansible playbook to generate terraform.tfvars.json
- **dry-run**: runs deploy script with --dry-run (preview only, no changes)
- **deploy**: runs deploy script live (main branch only)
- **remove**: manual trigger to remove bindings (main branch only)

### CI/CD Variables (GitLab → project → Settings → CI/CD → Variables)

Set these in BOTH the aci-lf-rplc and n5k projects:

| Variable | Value | Check "Mask" |
|----------|-------|-------------|
| `NDO_HOST` | NDO hostname or IP | No |
| `NDO_USERNAME` | NDO username | No |
| `NDO_PASSWORD` | NDO password | Yes |
| `VAULT_PASS` | Ansible vault password | Yes |

You can copy `NDO_USERNAME` and `NDO_PASSWORD` from the IPv6 project. `NDO_HOST` is just the hostname/IP (not the full URL like `NDO_URL`). `VAULT_PASS` is new — it's the password you used when running `ansible-vault encrypt`.

---

## GitLab Runner

| Detail | Value |
|--------|-------|
| Runner name | `aci-automation-runner` |
| Executor | Shell (NOT Docker) |
| Runner host | `apckw059aau0096` |
| Runner binary | `~/gitlab-runner/gitlab-runner` (on runner host) |
| Runs as | Background process (no systemd, no sudo) |

### Share the runner with new projects

The runner is registered to the IPv6 project. To use it for aci-lf-rplc and n5k:

1. In GitLab, go to the IPv6 project → Settings → CI/CD → Runners
2. Click the pencil icon on `aci-automation-runner`
3. Uncheck "Lock to current projects"
4. Go to each new project → Settings → CI/CD → Runners → enable it

### Start / restart the runner

```bash
ssh apckw059aau0096
pkill gitlab-runner
nohup ~/gitlab-runner/gitlab-runner run &
ps aux | grep gitlab-runner
```

Shows online in GitLab within 30 seconds. Re-run after any server reboot.

### Shell runner rules (important!)

Because this is a shell runner, CI files MUST follow these rules:

1. No `image:` line (that's Docker only)
2. No `---` at the top of the file
3. No `description:` or `value:` sub-keys under variables
4. Use `only:` not `rules:`
5. Inline everything in each job (no `extends:`)

---

## Scripts Quick Reference

### Deploying bindings

| Project | Command | What it does |
|---------|---------|-------------|
| aci-lf-rplc | `python3 deploy_bindings_python.py terraform.tfvars.json --dry-run` | Preview deployment |
| aci-lf-rplc | `python3 deploy_bindings_python.py terraform.tfvars.json` | Live deployment |
| n5k | `python3 deploy_bindings_python_v2.py terraform.tfvars.json --dry-run` | Preview deployment |
| n5k | `python3 deploy_bindings_python_v2.py terraform.tfvars.json` | Live deployment |

### Removing bindings

| Project | Command | What it does |
|---------|---------|-------------|
| both | `python3 selective_bindings_del.py --generate terraform.tfvars.json` | Generate removal file |
| both | `python3 selective_bindings_del.py bindings_to_remove.json --dry-run` | Preview removal |
| both | `python3 selective_bindings_del.py bindings_to_remove.json` | Live removal |

### Generating data

| Project | Command | What it does |
|---------|---------|-------------|
| aci-lf-rplc | `ansible-playbook process_data_LF.yml` | Transform epg_data.json → terraform.tfvars.json |
| n5k | `ansible-playbook process_data.yml` | Transform switch data → terraform.tfvars.json |
| n5k | `ansible-playbook get_active_ports.yml` | Gather port info from NX-OS switches |
| n5k | `ansible-playbook get_active_pc_ports5.yml` | Gather port-channel info from NX-OS switches |

---

## Vault files

Both projects use ansible-vault to store the NDO password.

| Project | Vault file | Password file | How to create |
|---------|-----------|---------------|--------------|
| aci-lf-rplc | `vault.yml` | `.vault_pass` | see below |
| n5k | `vault.yml` | `vault_pass.txt` | see below |

### Creating vault files manually

```bash
# Write your vault password to the password file
echo "your_vault_password" > .vault_pass    # aci-lf-rplc
echo "your_vault_password" > vault_pass.txt  # n5k

# Create and encrypt the vault file
echo "ndo_password: \"your_ndo_password\"" > /tmp/plain.yml
ansible-vault encrypt --vault-password-file .vault_pass --output vault.yml /tmp/plain.yml
rm /tmp/plain.yml
```

In CI, this is done automatically using the `VAULT_PASS` and `NDO_PASSWORD` variables.

---

## terraform_redesign_esg (for reference)

This is the IPv6/ESG Terraform project — separate from aci-lf-rplc and n5k.

| Detail | Value |
|--------|-------|
| Mac path | `/Users/johbarbe/DC/ACI/terraform-esg/` |
| CI file | `/Users/johbarbe/DC/ACI/terraform-esg/.gitlab-ci.yml` |
| CI handles | `ndo-terraform/` (NDO Terraform) and `aci-redesign/` (ACI APIC direct) |
| Pipeline docs | `/Users/johbarbe/DC/ACI/terraform-esg/ndo-terraform/PIPELINE_SETUP.md` |

### CI/CD Variables for this project

| Variable | Purpose |
|----------|---------|
| `NDO_USERNAME` / `NDO_PASSWORD` / `NDO_URL` | NDO credentials |
| `APIC_USERNAME` / `APIC_PASSWORD` / `APIC_URL` | APIC credentials |
| `TF_HTTP_USERNAME` / `TF_HTTP_PASSWORD` | GitLab state backend |
| `GITLAB_TOKEN` | MR comments |

### IPv4 redesign — current state (post-NDO cutover)

| Aspect | Lab | Prod (pending Terraform root) |
|--------|-----|-------------------------------|
| APIC data dirs | `data/nac-aci-site1/`, `data/nac-aci-site2/`, `data/nac-aci-shared/` | `data/nac-aci-site1-prod/`, `data/nac-aci-site2-prod/` (Design A: UCS-FI direct attach, no vPC) |
| VMM domains | `APCG-VDS1` (Site1) + `APCK-VDS1` (Site2), each adopts the matching pre-existing VDS in shared vCenter | same names |
| `dvs_version` | `unmanaged` (only safe value with vCenter 7.x/8.x against the `netascode/nac-aci` 0.7.0 validator) | same |
| Dynamic VLAN pool | `vmm-vlan-pool` 3501-3967 | same |
| Static VLAN pool | -- | `fi-static-vlan-pool` (213 VLANs in 93 ranges, sourced from live prod NDO) |
| FI uplink PGs | -- | `PC_FI_A` (eth1/6), `PC_FI_B` (eth1/7); `mac-pinning` (mode `mac-pin`); single-leaf, no vPC |
| Terraform roots | `apic-vmware/` (lab) + `ndo/` (lab+prod schema) | `apic-vmware-prod/` not yet created |

NDO schema `data/nac-ndo/schema-africom-v2.nac.yaml` is shared between lab and prod (same EPG model). The split is purely on the APIC access-policy side.

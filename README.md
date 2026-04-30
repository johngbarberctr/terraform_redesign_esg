# Cisco ACI Infrastructure as Code -- terraform_redesign_esg

## Security Warning

**DO NOT COMMIT CREDENTIALS TO THIS REPOSITORY.** All `.tfvars`, `.tfstate`, `vault.yml`, and credential files are excluded via `.gitignore`.

> **IMPORTANT**: All IP addresses, URLs, hostnames, usernames, and passwords shown in this README and sub-project READMEs are placeholders or examples. You **must** replace them with the actual production values for your environment (NDO IP, APIC IPs, GitLab URL, vCenter details, your credentials). Each sub-project README has specific instructions on which files to update. Ask the current project owner if you don't have the production values.

---

## Repository Overview

This repository contains Terraform and automation for the ACI IPv6 RCC deployment and ACI network redesign. It is hosted on GitLab at `sync.git.mil` (production) and `localhost:8080` (lab).

| Directory | Purpose | README |
|---|---|---|
| [`ndo-terraform/`](ndo-terraform/) | IPv6 RCC services via NDO Terraform (BDs, EPGs, L3Outs, port bindings) | [ndo-terraform/README.md](ndo-terraform/README.md) |
| [`aci-redesign/`](aci-redesign/) | ACI 2-VRF redesign (VRF-EUR + VRF-DMZ) via NAC-ACI module on APIC | [aci-redesign/README.md](aci-redesign/README.md) |
| [`docs/`](docs/) | Architecture docs, reports, deployment guides | [docs/README.md](docs/README.md) |
| [`data/`](data/) | NAC YAML blueprints and archived migration phase configs | — |

---

## Quick Start

### Prerequisites

- **Terraform** >= 1.0 (pinned providers: MSO ~> 1.5.0, ACI = 2.18.0)
- **Python** >= 3.7 with `requests`, `urllib3`
- **Git** access to the GitLab repo
- Network connectivity to NDO and/or APIC

### Production Server (RHEL 8)

```bash
# Clone the repo
git clone https://sync.git.mil/john.g.barber.ctr/my-new-ipv6-project.git
cd my-new-ipv6-project

# Set up Python venv (one-time)
python3 -m venv ~/my_venv
source ~/my_venv/bin/activate
pip install requests urllib3
```

Then follow the README in whichever subdirectory you need:
- **IPv6 RCC (NDO)**: `cd ndo-terraform` and follow [ndo-terraform/README.md](ndo-terraform/README.md)
- **ACI Redesign (APIC)**: `cd aci-redesign/apic-vmware` and follow [aci-redesign/README.md](aci-redesign/README.md)

### Lab (Local Mac)

The lab uses the same code with different credentials (`lab.tfvars` vs `prod.tfvars`) and a local Terraform state backend instead of the GitLab HTTP backend. See each subdirectory's README for lab-specific instructions.

---

## GitLab Project

| Detail | Value |
|---|---|
| Production GitLab | `https://sync.git.mil` |
| Lab GitLab | `http://localhost:8080` |
| Project ID (prod) | `38767` |
| Runner | Shell executor on `apckw059aau0096` (`aci-automation-runner`) |
| Git remote (prod) | `sync.git.mil/john.g.barber.ctr/my-new-ipv6-project` |
| Git remote (lab) | `localhost:8080/root/terraform_redesign_esg` |

### Pushing Changes

```bash
# Production
git push gitlab main

# Lab
git push gitlab main    # remote name is 'gitlab' for both
```

---

## CI/CD Pipeline

The root `.gitlab-ci.yml` handles both `ndo-terraform/` and `aci-redesign/` subdirectories. Each subdirectory also has its own `.gitlab-ci.yml` for project-specific jobs.

### Pipeline Stages

```
validate → plan → deploy → (destroy - manual)
```

### CI/CD Variables (Settings > CI/CD > Variables)

| Variable | Purpose | Masked |
|---|---|---|
| `TF_VAR_ndo_username` | NDO username | No |
| `TF_VAR_ndo_password` | NDO password | Yes |
| `TF_VAR_ndo_url` | NDO URL | No |
| `TF_VAR_apic_username` | APIC username | No |
| `TF_VAR_apic_password` | APIC password | Yes |
| `TF_VAR_apic_g_url` | APIC Site G URL | No |
| `TF_VAR_apic_k_url` | APIC Site K URL | No |
| `TF_VAR_vrf_template_name` | `UpgradeTemplate1` (prod) | No |
| `TF_STATE_TOKEN` | GitLab Personal Access Token (api scope) for state backend | Yes |

### GitLab Runner

The runner is a user-local binary on the RHEL server (no sudo, no systemd). There are **two servers** with runners:

| Server | Hostname | Projects |
|--------|----------|----------|
| `apckw059aau0096` | aci-automation-runner | ndo-terraform, aci-redesign |
| `APCKW059AAU0018` | — | n5k, aci-lf-rplc |

**Step 1: SSH into the correct server** and check which one you're on:

```bash
hostname
```

**Step 2: Find the runner binary** (path may vary per server):

```bash
find /home/john.g.barber.ctr -name "gitlab-runner" -type f 2>/dev/null
find /Viper -name "gitlab-runner" -type f 2>/dev/null
```

**Step 3: Check if the runner is running:**

```bash
ps aux | grep gitlab-runner | grep -v grep
```

If that returns nothing, the runner is not running.

**Step 4: Start (or restart) the runner** using the path you found in step 2:

```bash
# Start (replace path if different on your server)
nohup ~/gitlab-runner/gitlab-runner run &

# Restart (kill stale + start fresh)
pkill gitlab-runner && nohup ~/gitlab-runner/gitlab-runner run &
```

The runner should show as online in GitLab within 30 seconds.

**Auto-start on reboot** (the runner is a background process — it dies on reboot):

On `apckw059aau0096` (ndo-terraform/aci-redesign):

```bash
crontab -e
# Add these lines:
@reboot nohup /home/john.g.barber.ctr/gitlab-runner/gitlab-runner run &
*/5 * * * * pgrep -f "gitlab-runner run" > /dev/null || nohup /home/john.g.barber.ctr/gitlab-runner/gitlab-runner run &
```

On `APCKW059AAU0018` (n5k/aci-lf-rplc):

```bash
crontab -e
# Add these lines:
@reboot nohup /home/john.g.barber.ctr/gitlab-runner run &
*/5 * * * * pgrep -f "gitlab-runner run" > /dev/null || nohup /home/john.g.barber.ctr/gitlab-runner run &
```

The `@reboot` line starts the runner after a reboot. The `*/5` line checks every 5 minutes and restarts it if it crashed.

**Shell runner rules for `.gitlab-ci.yml`:**

1. No `image:` directive (Docker only)
2. No `---` YAML document start marker
3. No expanded variable syntax (`description:` / `value:` sub-keys)
4. Use `only:` instead of `rules:`
5. Always 2 spaces for indentation, never tabs

---

## Related Projects

| Project | GitLab Repo | Purpose |
|---|---|---|
| N5K Migration | `n5k_replacement` | N5K switch migration and ACI leaf replacement |
| NDO NAC Terraform | `ndo_terraform` | Full NDO NAC configs (schema, sites, Robot Framework tests) |

See [PROJECT_MAP.md](PROJECT_MAP.md) for the complete cross-project reference.

---

## Files NOT in Git

These are excluded via `.gitignore` and must be created locally:

| File | Purpose |
|---|---|
| `*.tfvars` | Terraform credentials |
| `*.tfstate*` | Terraform state |
| `.terraform/` | Provider cache |
| `vault.yml` / `vault_pass.txt` | Ansible Vault |
| `backend.hcl` | Local backend config |
| `*.json` | Generated data files |

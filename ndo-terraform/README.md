# Cisco ACI NDO/MSO -- IPv6 RCC Services Deployment

## Security Warning

**DO NOT COMMIT CREDENTIALS TO THIS REPOSITORY**

The following files contain sensitive information and are excluded via `.gitignore`:
- `terraform.tfvars`, `lab.tfvars`, `prod.tfvars` -- NDO/APIC credentials
- `terraform.tfstate*` -- may contain sensitive data
- `vault.yml`, `vault_pass.txt` -- Ansible Vault credentials
- `.terraform/` -- provider binaries and cache
- `backend.hcl` -- GitLab state backend token

Always use environment variables or secure credential management for production deployments.

---

## Table of Contents

1. [Overview](#overview)
2. [Getting Started (New User Setup)](#getting-started-new-user-setup)
3. [Repository Structure](#repository-structure)
4. [Terraform State Backend](#terraform-state-backend)
5. [Running Terraform](#running-terraform)
6. [CI/CD Pipeline](#cicd-pipeline)
7. [Deployment Guide](#deployment-guide)
8. [Architecture Overview](#architecture-overview)
9. [Automation Scripts](#automation-scripts)
10. [Troubleshooting](#troubleshooting)
11. [Maintenance](#maintenance)
12. [Key Decisions and Rationale](#key-decisions-and-rationale)
13. [FAQ](#faq)

---

## Overview

This repository contains Terraform configurations and Python automation for deploying IPv6-enabled Regional Computing Center (RCC) services in Cisco ACI Multi-Site Orchestrator (MSO/NDO). It manages:

- **1 VRF** (VRF-RCC)
- **33 Bridge Domains** with IPv6 subnets
- **33 Endpoint Groups (EPGs)** for service segmentation
- **~200 static port bindings** via Python automation
- **Multi-site deployment** across AEDCG (Grafenwoehr) and AEDCK (Kaiserslautern)
- **VLAN range:** 3000-3032

### GitLab Project

- **URL**: `https://sync.git.mil/john.g.barber.ctr/my-new-ipv6-project`
- **Project ID**: `38767`
- **Runner**: Shell executor on `apckw059aau0096` (`aci-automation-runner`)

---

## Getting Started (New User Setup)

This section walks through setting up your own working directory and Python virtual environment on the RHEL server to run Terraform and the automation scripts.

### 1. Clone the Repository

```bash
cd ~
git clone https://sync.git.mil/john.g.barber.ctr/my-new-ipv6-project.git
cd my-new-ipv6-project/ndo-terraform
```

### 2. Create a Python Virtual Environment

```bash
python3 -m venv ~/my_venv
source ~/my_venv/bin/activate
pip install requests urllib3
```

Activate this venv before running any Python scripts or Ansible playbooks:

```bash
source ~/my_venv/bin/activate
```

### 3. Install Terraform

If Terraform is not already installed, check if it's available:

```bash
terraform version
```

If not, ask the infrastructure team for the Terraform binary location, or copy it from an existing user's setup. The project requires Terraform >= 1.0.

### 4. Configure Credentials

> **IMPORTANT**: All IP addresses, URLs, usernames, and passwords shown in this README are placeholders. You **must** replace them with the actual production values for your environment (NDO IP, APIC IPs, GitLab URL, your username, your passwords). The production values are stored in the GitLab CI/CD variables and in the `terraform.tfvars` file on the RHEL server — ask the current project owner if you don't have them.

Create a `terraform.tfvars` file (this file is gitignored and will not be committed):

```bash
cat > terraform.tfvars << 'EOF'
ndo_username = "your_username"
ndo_password = "your_password"
ndo_url      = "https://x.x.x.x"
EOF
chmod 600 terraform.tfvars
```

Replace `x.x.x.x` with the actual production NDO management IP address, and use your real NDO credentials.

For lab use, copy `lab.tfvars` to `terraform.tfvars` and fill in the values. For production, copy `prod.tfvars`.

### 5. Initialize Terraform with Remote State

The project uses a GitLab HTTP backend for shared Terraform state. Initialize it once:

```bash
terraform init -reconfigure \
  -backend-config="address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform" \
  -backend-config="lock_address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform/lock" \
  -backend-config="unlock_address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform/lock" \
  -backend-config="username=your_gitlab_username" \
  -backend-config="password=YOUR_PERSONAL_ACCESS_TOKEN" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
```

To get the token: go to GitLab (`https://sync.git.mil`) > your project > **Settings > CI/CD > Variables** > reveal the `TF_STATE_TOKEN` value. Or create your own Personal Access Token with `api` scope under **User Settings > Access Tokens**.

After this one-time init, the backend config is cached in `.terraform/` and you can run `terraform plan`/`apply` normally.

### 6. Verify Setup

```bash
terraform plan -refresh=false -parallelism=3
```

This should show the current planned changes without errors.

---

## Repository Structure

### Files in Git

| File | Purpose |
|---|---|
| `main.tf` | Terraform backend and provider configuration (provider versions pinned) |
| `variables.tf` | Variable definitions (NDO credentials, template names) |
| `bds_epgs.tf` | Main Terraform config (~4200 lines): VRF, BDs, EPGs, contracts |
| `l3outs_apic.tf` | L3Out configuration for APIC |
| `vlans_apic.tf` | VLAN pool configuration for APIC |
| `.gitlab-ci.yml` | CI/CD pipeline definition |
| `.gitignore` | Git exclusion rules |
| `README.md` | This file |

### Files NOT in Git (gitignored)

| File | Purpose |
|---|---|
| `terraform.tfvars` | Active credentials |
| `lab.tfvars` | Lab-specific variable values |
| `prod.tfvars` | Production-specific variable values |
| `backend.hcl` | Backend config for local CLI use (optional) |
| `terraform.tfstate*` | State files |
| `.terraform/` | Provider cache |
| `vault.yml` | Ansible Vault encrypted passwords |
| `generate_ipv6_bindings3.py` | Port binding automation script |

### Disabled/Offline Files

Files with `.disabled` or `.offline` extensions are inactive Terraform configs kept for reference. Terraform ignores them.

---

## Terraform State Backend

### Why Remote State

Without shared state, the pipeline starts with a blank `terraform.tfstate` and tries to create all resources from scratch. NDO rejects these with "already exists" errors. The GitLab HTTP backend stores state centrally so both command-line and pipeline operations share the same view.

### Initial State Migration (Already Done)

This was run once to push existing local state to GitLab:

```bash
terraform init -migrate-state \
  -backend-config="address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform" \
  -backend-config="lock_address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform/lock" \
  -backend-config="unlock_address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform/lock" \
  -backend-config="username=john.g.barber.ctr" \
  -backend-config="password=<PERSONAL_ACCESS_TOKEN>" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
```

### State Refresh and NDO API Limits

With ~200+ resources, a full `terraform plan` triggers hundreds of API calls to NDO. Even at `-parallelism=1`, this can overwhelm NDO and cause session timeouts, authentication errors, or provider crashes.

**Current solution: always use `-refresh=false`**

```bash
terraform plan -parallelism=3 -refresh=false -out=plan.tfplan
```

This tells Terraform to trust the existing state and only process changes in `.tf` files. The pipeline also uses `-refresh=false`.

**What you lose**: Terraform will not detect drift. If someone changes something directly in NDO, Terraform won't know. This is acceptable because all changes should go through Terraform or the Python scripts.

**Periodic full refresh**: To verify state matches NDO (e.g., before a major change), run during off-hours:

```bash
nohup terraform plan -parallelism=1 > refresh_output.log 2>&1 &
```

Use `-parallelism=1` for full refreshes. Expect intermittent auth errors -- retry if needed.

### Lab vs Production State

Lab and production use **separate Terraform state files** against different NDO instances. Never point lab at the production state backend.

| Setting | Lab | Production |
|---|---|---|
| VRF Template Name | `VRF_Template` | `UpgradeTemplate1` |
| MSO Provider `domain` | `"local"` | omitted (`null`) |
| MSO Provider `platform` | `"nd"` | omitted (`null`) |
| NDO URL | Lab NDO | Production NDO |
| State Backend | Local file | GitLab HTTP backend |

---

## Running Terraform

### From the Command Line (Production Server via SSH)

Step-by-step, in order:

**Step 1: Go to the project directory**

```bash
cd ~/my-new-ipv6-project/ndo-terraform
```

**Step 2: Initialize Terraform (one-time, or after deleting .terraform/)**

```bash
terraform init -reconfigure \
  -backend-config="address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform" \
  -backend-config="lock_address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform/lock" \
  -backend-config="unlock_address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform/lock" \
  -backend-config="username=john.g.barber.ctr" \
  -backend-config="password=YOUR_TF_STATE_TOKEN" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
```

You only need to do this once. After that, the backend config is cached in `.terraform/` and you skip this step.

**Step 3: Plan (always do this before apply)**

Long-running operations can be killed by SSH timeouts. Use `nohup`:

```bash
nohup terraform plan -parallelism=3 -refresh=false -out=plan.tfplan > plan_output.log 2>&1 &
tail -f plan_output.log
```

Review the output. It should show what will be created/changed/destroyed.

**Step 4: Apply the plan**

```bash
nohup terraform apply -parallelism=3 "plan.tfplan" > apply_output.log 2>&1 &
tail -f apply_output.log
```

**If your SSH session drops**, reconnect and check on the job:

```bash
jobs -l
ps aux | grep terraform
tail -f apply_output.log
```

The Terraform process continues in the background regardless.

**Targeted apply (only specific resources):**

```bash
nohup terraform apply -parallelism=1 -auto-approve -refresh=false \
  -target=mso_schema_template_bd_subnet.bd_example_subnet \
  > apply_output.log 2>&1 &
tail -f apply_output.log
```

**Targeted refresh (verify state matches NDO for one resource):**

```bash
terraform plan -refresh=true -parallelism=1 -target=mso_schema_template_bd_subnet.bd_fmwr_svr_subnet
```

### From the Command Line (Lab / Local Mac)

```bash
terraform init
terraform plan -var-file="lab.tfvars" -parallelism=3 -out=plan.tfplan
terraform apply "plan.tfplan"
```

The lab uses a local state file by default.

### Why `-parallelism=3`

The NDO API throttles concurrent requests. At higher values (5+), session tokens expire or get invalidated under load. `-parallelism=3` is the highest reliable value. Do not increase it unless NDO API behavior changes.

---

## CI/CD Pipeline

### Pipeline Flow

```
git push to main or merge request
    |
    v
[validate] --> terraform fmt -check (allowed to fail)
    |
    v
[plan] --> terraform init (with backend config)
       --> terraform plan -out=plan.tfplan -parallelism=3 -refresh=false
       --> saves plan.tfplan and plan.txt as artifacts
    |
    v
[deploy] --> terraform init (with backend config)
         --> terraform apply plan.tfplan -parallelism=3
         --> runs automatically on main branch

[destroy] --> manual trigger only
```

### GitLab CI/CD Variables

All variables are configured in **Settings > CI/CD > Variables**. They must be **Protected** (the `main` branch is also protected).

#### Terraform Provider Credentials

These use the `TF_VAR_` prefix so Terraform reads them directly as environment variables -- no `export` commands needed.

| Variable Name | Purpose | Masked |
|---|---|---|
| `TF_VAR_ndo_username` | NDO/MSO username | No |
| `TF_VAR_ndo_password` | NDO/MSO password | Yes |
| `TF_VAR_ndo_url` | NDO URL (e.g., `https://x.x.x.x`) | No |
| `TF_VAR_apic_username` | APIC username | No |
| `TF_VAR_apic_password` | APIC password | Yes |
| `TF_VAR_apic_g_url` | APIC Site G URL | No |
| `TF_VAR_apic_k_url` | APIC Site K URL | No |
| `TF_VAR_vrf_template_name` | Set to `UpgradeTemplate1` | No |

**Important**: Variables use the `TF_VAR_` prefix intentionally. Earlier attempts using plain names with shell `export` caused authentication failures because double-quote expansion mangled passwords with special characters.

#### State Backend Token

| Variable Name | Purpose | Masked |
|---|---|---|
| `TF_STATE_TOKEN` | GitLab Personal Access Token (API scope) for state locking | Yes |

This token is used instead of `CI_JOB_TOKEN` because the job token did not have sufficient permissions for state locking on this GitLab instance.

### GitLab Runner

The runner is a user-local binary on the RHEL server (no sudo, no systemd). There are **two servers** with runners:

| Server | Hostname | Projects |
|--------|----------|----------|
| `apckw059aau0096` | aci-automation-runner | ndo-terraform, aci-redesign |
| `APCKW059AAU0018` | — | n5k, aci-lf-rplc |

This project (`ndo-terraform`) runs on **`apckw059aau0096`**.

**Step 1: SSH into the server** and verify which one you're on:

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
```

The message `nohup: ignoring input and appending output to 'nohup.out'` is normal.

If multiples appear or it's stuck, kill and restart:

```bash
pkill gitlab-runner && nohup ~/gitlab-runner/gitlab-runner run &
```

The runner should show as online in GitLab within 30 seconds.

**Auto-start on reboot** (the runner is a background process — it dies on reboot):

On `apckw059aau0096` (this project's runner):

```bash
crontab -e
# Add these lines:
@reboot nohup /home/john.g.barber.ctr/gitlab-runner/gitlab-runner run &
*/5 * * * * pgrep -f "gitlab-runner run" > /dev/null || nohup /home/john.g.barber.ctr/gitlab-runner/gitlab-runner run &
```

On `APCKW059AAU0018` (n5k/aci-lf-rplc runner):

```bash
crontab -e
# Add these lines:
@reboot nohup /home/john.g.barber.ctr/gitlab-runner run &
*/5 * * * * pgrep -f "gitlab-runner run" > /dev/null || nohup /home/john.g.barber.ctr/gitlab-runner run &
```

The `@reboot` line starts the runner after a reboot. The `*/5` line checks every 5 minutes and restarts it if it crashed.

**Registering a new runner:**

Go to GitLab > Settings > CI/CD > Runners > create a new runner to get a token, then:

```bash
~/gitlab-runner/gitlab-runner register \
  --url https://sync.git.mil \
  --token YOUR_NEW_TOKEN \
  --executor shell
```

Use the `shell` executor (Docker is not installed on this host).

**Shell runner rules for `.gitlab-ci.yml`:**

1. No `image:` directive -- that's for Docker runners only
2. No `---` YAML document start marker -- causes parse failures on this GitLab instance
3. No expanded variable syntax -- use simple `KEY: "value"` pairs under `variables:`
4. Use `only:` instead of `rules:` -- simpler and universally supported
5. No YAML anchors or multiline blocks -- keep syntax flat
6. Avoid copy-paste from email or rich text -- invisible formatting characters break YAML
7. Always use 2 spaces for indentation, never tabs

---

## Deployment Guide

### Phase 1: Terraform (Logical Infrastructure)

```bash
# 1. Configure credentials in terraform.tfvars (see Getting Started)

# 2. Initialize Terraform (see Getting Started step 5)

# 3. Review planned changes
nohup terraform plan -parallelism=3 -refresh=false -out=plan.tfplan > plan_output.log 2>&1 &
tail -f plan_output.log

# 4. Deploy infrastructure
nohup terraform apply -parallelism=3 "plan.tfplan" > apply_output.log 2>&1 &
tail -f apply_output.log

# Duration: 8-12 minutes
# Creates: VRF, contracts, 33 BDs, 33 EPGs, site associations, domains (~304 resources)
```

### Phase 1.5: vzAny Configuration (REQUIRED -- Manual)

**This step cannot be automated** due to a Terraform provider limitation.

1. Login to NDO/MSO GUI
2. Navigate to: **Schemas > AEDCE > UpgradeTemplate1 > VRF-RCC**
3. Check the **vzAny** checkbox
4. Under **vzAny Provider Contracts**: click **+ Contract**, select `Any_VRF-RCC`
5. Under **vzAny Consumer Contracts**: click **+ Contract**, select `Any_VRF-RCC`
6. Click **Save**
7. Click **Deploy** > check both sites (AEDCG, AEDCK) > Deploy

Duration: 2-3 minutes. One-time setup -- rarely changes.

### Phase 2: Python Automation (Physical Port Bindings)

```bash
source ~/my_venv/bin/activate

# Check current bindings (optional, read-only)
python3 generate_ipv6_bindings3.py check

# Generate bindings JSON
python3 generate_ipv6_bindings3.py generate

# Deploy port bindings
python3 generate_ipv6_bindings3.py deploy

# Duration: 30-60 seconds
# Creates: ~200 static port bindings
```

### Verification

```bash
# Verify bindings
python3 generate_ipv6_bindings3.py check

# Verify no management ports leaked through
grep -E "paths-10[12]|protpaths-101-102" ipv6_rcc_port_bindings.json
# Should return nothing
```

---

## Architecture Overview

### Network Design

- **1 VRF**: VRF-RCC with vzAny for intra-VRF communication
- **33 Bridge Domains** with IPv6 subnets (`2609:efff:b33b:xxxx::1/64`)
- **33 EPGs** organized into service categories
- **Multi-site**: AEDCG (Grafenwoehr) and AEDCK (Kaiserslautern)
- **VLANs**: 3000-3032

### Service Categories

| Category | EPGs | VLANs |
|---|---|---|
| Infrastructure Management | NAC, CFG-MGMT, GEF-MGMT, MECM | 3000-3003 |
| Network Services | LB, DNS-MGMT, RCC-DNS, DHCP-SVR, SMTP-SVR | 3004-3008 |
| Voice & Communications | VVOIP-MGMT, VVOIP-PROXY, LMR, E911-SVR | 3009-3012 |
| Security Services | ACAS-SCANNERS, C2C-SCANNERS, OCSP, PKI-SRV | 3013-3016 |
| Directory & Authentication | AD, ADFS | 3017-3018 |
| Proxy Services | D64-PROXY, RWEB-PROXY, FWEB-PROXY | 3019-3021 |
| Application & Web Servers | APP-SVR, WEB-SVR, FMWR-SVR | 3022-3024 |
| RCC Services | RCC-SVR, RCC-DCO, RCC-UNIX | 3025-3027 |
| Storage Services | PRINT-SVR, FILE-SVR, BACKUP-SVR | 3028-3030 |
| Database & Logging | DB-SVR, SYSLOG | 3031-3032 |

### Template Distribution

| Template | BDs | EPGs | Stretch | Sites | Purpose |
|---|---|---|---|---|---|
| UpgradeTemplate1 | 0 | 0 | N/A | N/A | VRF and contracts only |
| L2_Stretched | 29 | 29 | Yes | Both | Production services |
| G-Specific_Only | 1 | 1 | No | AEDCG | GEF Management |
| K-Specific_Only | 1 | 1 | No | AEDCK | Backup Services |
| L2_Non-Stretched | 2 | 2 | No | Both | Database, Logging |

### Port Binding Patterns

**Standard Pattern (most EPGs):**

```
AEDCG: VPC_D1A-B (nodes 111-112), VPC_D2A-B (nodes 111-112)
AEDCK: VPC_D1A-B (nodes 111-112), VPC_D2A-B (nodes 111-112), VPC_D3A-B (nodes 111-112)
```

**GEF Management (EPG-GEF-MGMT only):**

```
AEDCG only: VPC_D1A-B, VPC_D2A-B, VPC_GEF_A-B (nodes 111-112)
```

**Excluded:** Leaves 101/102 and VPC_Transport (management nodes -- production traffic uses nodes 111-112 only).

### IPv6 Addressing

```
2609:efff:b33b:XX00::1/64

XX = service category:
  10 = Infrastructure Management
  20 = Network Services
  30 = Voice/Communications
  40 = Security Services
  50 = Directory/Auth
  60 = Proxy Services
  70 = App/Web Servers
  80 = RCC Services
  90 = Storage Services
  a0 = Database/Logging
```

---

## Automation Scripts

### generate_ipv6_bindings3.py

Auto-generates and deploys port bindings for IPv6 RCC EPGs based on existing IPv4 infrastructure.

```bash
python3 generate_ipv6_bindings3.py check     # View current bindings (read-only)
python3 generate_ipv6_bindings3.py generate   # Generate JSON only
python3 generate_ipv6_bindings3.py deploy     # Generate and deploy
```

Features:
- Auto-discovers RCC EPGs across all templates
- Maps to functionally similar IPv4 EPGs
- Filters out management ports (leaves 101/102)
- Multi-site and template-aware

---

## Troubleshooting

### Terraform Errors

**"HTTP remote state endpoint requires auth"**

The `.terraform/` directory is missing cached backend config. Re-run `terraform init` with the full `-backend-config` flags (see [Getting Started step 5](#5-initialize-terraform-with-remote-state)).

**"Error acquiring the state lock"**

A previous operation didn't finish cleanly:

```bash
terraform force-unlock <LOCK_ID>
```

The Lock ID is shown in the error message.

**"Invalid username or password"**

Intermittent. Caused by NDO API session timeout during large operations.

Fixes:
- Use `-refresh=false` (primary fix)
- Use `-parallelism=3` (max safe value)
- Use `-target=` to limit scope
- Re-run -- it often passes on retry
- Drop to `-parallelism=1` for stubborn failures

**"Provider produced inconsistent result after apply"**

The MSO provider creates a resource but cannot read it back. Known bug with IPv6 addresses containing leading-zero hex groups (e.g., `0100`). The `bd_nms_subnet` resource is commented out for this reason and managed manually in NDO.

If this happens:
1. Check NDO GUI -- the resource was likely created
2. Comment out the resource and manage manually
3. Do NOT retry -- it will create duplicates

**"request cancelled: grpcprovider" / "plugin did not respond"**

Provider crashed or timed out waiting for NDO. Fix: use `-refresh=false` and/or `-target=`.

**"Duplicate Resource" / "already exists"**

Resource exists on NDO but not in Terraform state. Options:
1. Import: `terraform import <resource_address> <import_id>`
2. Delete from NDO and let Terraform recreate it

**"Subnets defined on non-stretched BD"**

Set `layer2_stretch = true` on all BDs with subnets. This enables L3 routing but doesn't actually stretch -- site associations control that.

### Pipeline YAML Errors

**"config should implement the script:, run:, or trigger: keyword"**

Usually caused by invisible characters (tabs, BOM markers) from copy-paste. Use the GitLab Pipeline Editor (Build > Pipeline editor) for validation, or paste into `vi` on the server.

### vzAny Issues

**EPGs cannot communicate:**

1. Verify vzAny enabled: VRF-RCC > vzAny checkbox checked
2. Verify contracts: Provider and Consumer both have `Any_VRF-RCC`
3. Verify deployed to both sites
4. Check endpoint learning in APIC

**vzAny checkbox grayed out:**

Save the VRF first, then refresh the browser.

### Python Script Errors

**No RCC EPGs found:**

Run `terraform apply` first to create the EPGs. Wait 1-2 minutes for sync.

**Authentication failed:**

Verify NDO host, credentials, and network connectivity.

---

## Maintenance

### Adding New EPGs

1. Add resources to `bds_epgs.tf` (BD, subnet, EPG, site associations, domains)
2. Run `terraform apply`
3. Run `python3 generate_ipv6_bindings3.py deploy`
4. The script auto-discovers new EPGs

### Importing Existing Resources

If resources exist on NDO but not in Terraform state:

```bash
terraform state show data.mso_schema.existing    # get schema_id
terraform state show data.mso_site.aedck          # get site_id

terraform import mso_schema_template_bd_subnet.bd_example_subnet \
  "<schema_id>/template/L2_Stretched/bd/BD-EXAMPLE/subnet/<ip>"
```

### Backup Before Major Changes

```bash
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
git add -A && git commit -m "Backup before changes" && git push
```

---

## Key Decisions and Rationale

| Decision | Rationale |
|---|---|
| `TF_VAR_` prefix on CI/CD variables | Terraform reads them directly; avoids shell `export` that mangled special characters |
| Personal Access Token for state | `CI_JOB_TOKEN` lacked state locking permissions |
| ACI provider pinned to `= 2.18.0` | Newer versions broke APIC authentication; do not use `>= 2.0.0` |
| MSO provider pinned to `~> 1.5.0` | Ensures consistent behavior across environments |
| `-parallelism=3` | Highest safe value; higher causes NDO API timeouts |
| `-refresh=false` on plan | Prevents NDO API overload; drift detection done manually |
| GitLab HTTP backend | Shares state between CLI and pipeline |
| Python for port bindings | 20x faster than Terraform (30 sec vs 10 min) |
| Single VRF | Simplified routing; all RCC services are trusted |
| 33 BDs (one per EPG) | Maximum flexibility; independent subnet management |
| Filter management ports | Clean separation of production and management planes |
| `bd_nms_subnet` commented out | Provider bug with leading-zero hex groups; managed manually |
| `nohup` for SSH runs | Prevents timeouts from killing long Terraform operations |
| `retry: max: 2` on pipeline | NDO auth errors are intermittent; retry usually succeeds |
| `var.vrf_template_name` | Single codebase for lab (`VRF_Template`) and prod (`UpgradeTemplate1`) |

---

## IPv6 Address Migration Notes (Feb 2026)

All BD subnet gateway IPs were migrated from short-form IPv6 (e.g., `e300::1/64`) to full-prefix form (e.g., `2609:efff:b33b:e300::1/64`). During migration, an SSH disconnect caused three resources to be created on NDO but not saved to state. These were resolved by deleting from NDO and running targeted applies.

---

## FAQ

**Q: Why can't Terraform configure vzAny?**
A: MSO Terraform provider limitation. Manual GUI config required (one-time, 2-3 minutes).

**Q: Why use Python instead of Terraform for port bindings?**
A: Python is 20x faster (30 sec vs 10 min) due to batch API operations.

**Q: Can I add more EPGs later?**
A: Yes. Add to Terraform, apply, then run the Python script. It auto-discovers new EPGs.

**Q: What if I need different security policies?**
A: Add EPG-to-EPG contracts in addition to vzAny. vzAny provides baseline connectivity.

**Q: How do I roll back?**
A: Lab: `terraform destroy` then redeploy. Production: use `terraform state` management and selective removal.

**Q: Do I need to configure vzAny every time?**
A: No. One-time setup. Future Terraform runs don't affect it.

**Q: Are port paths identical at both sites?**
A: Yes. VPC policy group names are logical and reference site-specific physical configs.

---

## Resource Summary

| Type | Count | Method |
|---|---|---|
| VRF | 1 | Terraform |
| Contracts | 1 | Terraform |
| Bridge Domains | 33 | Terraform |
| BD Subnets | 33 | Terraform |
| Application Profiles | 3 | Terraform |
| EPGs | 33 | Terraform |
| Site Associations | ~134 | Terraform |
| EPG Domain Associations | 66 | Terraform |
| vzAny Contract Bindings | 2 | Manual (GUI) |
| Static Port Bindings | ~200 | Python |
| **Grand Total** | **~506** | |

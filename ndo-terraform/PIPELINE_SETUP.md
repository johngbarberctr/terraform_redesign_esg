# NDO-Terraform CI/CD Pipeline Setup

Documentation of the GitLab CI/CD pipeline configuration for the `ndo-terraform` project, including remote state management, credential handling, and troubleshooting notes.

## GitLab Project

- **URL**: `https://sync.git.mil/john.g.barber.ctr/my-new-ipv6-project`
- **Project ID**: `38767`
- **Runner**: Shell executor on `apckw059aau0096` (`aci-automation-runner`)

---

## Files Modified

### `main.tf`

Added the GitLab HTTP backend for shared remote state:

```hcl
terraform {
  backend "http" {}

  required_providers {
    mso = {
      source  = "CiscoDevNet/mso"
      version = ">= 1.5.2"
    }
    aci = {
      source  = "CiscoDevNet/aci"
      version = ">= 2.0.0"
    }
  }
}
```

The `backend "http" {}` block is empty because all backend configuration is passed via `-backend-config` flags during `terraform init`. This keeps credentials out of code.

**Note**: The provider block now uses `var.mso_domain` and `var.mso_platform` instead of hardcoded values. In production both default to `null` (omitted). In the lab, `lab.tfvars` sets `mso_domain = "local"` and `mso_platform = "nd"`. See "Lab vs Production Environments" below.

### `.gitlab-ci.yml`

Created a pipeline with three stages: `validate`, `plan`, `deploy`.

- **validate**: Runs `terraform fmt -check` (allowed to fail).
- **plan**: Initializes backend, runs `terraform plan`, saves plan as artifact.
- **deploy**: Initializes backend, applies the saved plan. Runs only on `main`.
- **destroy**: Manual job for tearing down resources. Runs only on `main`.

Each job runs `terraform init` with full `-backend-config` flags to connect to the GitLab HTTP state backend.

Key settings:
- `-parallelism=3` on all plan/apply/destroy commands (maximum safe value for NDO API)
- `-refresh=false` on plan to skip state refresh (prevents NDO API timeout; see "State Refresh" below)
- `-input=false` to prevent interactive prompts
- Plan file (`plan.tfplan`) is passed as a pipeline artifact from `plan` to `deploy`

### `.gitignore`

Updated to exclude:
- Terraform state files (`*.tfstate`, `*.tfvars`, `.terraform/`, `*.tfplan`)
- Build artifacts (`builds/`, `.archive/`)
- Generated data files (`*.json`, `*.zip`)
- Credentials (`*password*`, `*secret*`, `*token*`, `vault_pass.txt`)
- Python artifacts, IDE files, logs

---

## GitLab CI/CD Variables

All variables are configured in **Settings > CI/CD > Variables**. They must be:
- **Protected**: Yes (the `main` branch is also protected)
- **Environment scope**: `All (default)`

### Terraform Provider Credentials

These are named with the `TF_VAR_` prefix so Terraform reads them directly as environment variables -- no `export` commands needed in the pipeline scripts.

| Variable Name | Purpose | Masked |
|---|---|---|
| `TF_VAR_ndo_username` | NDO/MSO username | No |
| `TF_VAR_ndo_password` | NDO/MSO password | Yes |
| `TF_VAR_ndo_url` | NDO URL (e.g., `https://x.x.x.x`) | No |
| `TF_VAR_apic_username` | APIC username | No |
| `TF_VAR_apic_password` | APIC password | Yes |
| `TF_VAR_apic_g_url` | APIC Site G URL | No |
| `TF_VAR_apic_k_url` | APIC Site K URL | No |

**Important**: These variables use the `TF_VAR_` prefix intentionally. Earlier attempts using plain names (e.g., `NDO_PASSWORD`) with `export TF_VAR_ndo_password="$NDO_PASSWORD"` in the script caused intermittent authentication failures because the shell's double-quote expansion mangled passwords containing special characters.

### State Backend Token

| Variable Name | Purpose | Masked |
|---|---|---|
| `TF_STATE_TOKEN` | GitLab Personal Access Token (API scope) for state locking | Yes |

This token is used instead of `CI_JOB_TOKEN` because the job token did not have sufficient permissions for state locking on this GitLab instance.

---

## Remote State Setup

### Why Remote State

Without shared state, the pipeline starts with a blank `terraform.tfstate` and tries to create all resources from scratch. NDO rejects these with "already exists" errors. The GitLab HTTP backend stores state centrally so both command-line and pipeline operations share the same state.

### Initial State Migration

This was run once on the remote system to push the existing local state to GitLab:

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

Answered "yes" when prompted to copy existing state to the new backend.

### Command-Line Usage (After Migration)

To run Terraform from the command line after the backend is configured, use the same `-backend-config` flags with `terraform init`:

```bash
terraform init \
  -backend-config="address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform" \
  -backend-config="lock_address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform/lock" \
  -backend-config="unlock_address=https://sync.git.mil/api/v4/projects/38767/terraform/state/ndo-terraform/lock" \
  -backend-config="username=john.g.barber.ctr" \
  -backend-config="password=<PERSONAL_ACCESS_TOKEN>" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
```

Then run `terraform plan` and `terraform apply` as normal. The `terraform.tfvars` file provides the NDO/APIC credentials for command-line runs.

---

## State Refresh and NDO API Limits

### The Problem

With ~200+ resources in `bds_epgs.tf`, a full `terraform plan` or `terraform apply` triggers a state refresh that makes hundreds of API calls to NDO. Even at `-parallelism=1`, this can overwhelm NDO and cause:

- `"Invalid username or password"` -- NDO session token expires mid-refresh
- `"plugin did not respond"` -- Terraform provider crashes waiting for NDO
- `"request cancelled: grpcprovider"` -- provider times out during `UpgradeResourceState`

### Current Solution: `-refresh=false`

Use `-refresh=false` on plan and apply to skip the state refresh entirely. Terraform trusts the existing state and only processes changes in the `.tf` files.

```bash
nohup terraform plan -parallelism=3 -refresh=false -out=plan.tfplan > plan_output.log 2>&1 &
nohup terraform apply -parallelism=3 "plan.tfplan" > apply_output.log 2>&1 &
```

The pipeline `.gitlab-ci.yml` also uses `-refresh=false` on the plan stage.

### Tradeoffs and Risks of `-refresh=false`

**What you lose**: Terraform will not detect drift -- if someone makes a change directly in NDO (or NDO drifts on its own), Terraform won't know. It could overwrite manual changes, skip needed updates, or have an inconsistent view of the real state.

**When it matters**: If other people start making changes directly in NDO, or if NDO resources change outside of Terraform (e.g., template deployments, policy pushes), the state file will be stale and Terraform could make bad decisions.

**Why it's necessary for now**: The CiscoDevNet/mso provider doesn't handle large resource counts well. The provider opens too many sessions and NDO invalidates them.

### Better Long-Term Solutions

1. **Split into smaller state files**: Break `bds_epgs.tf` into separate Terraform modules or workspaces (e.g., one per site, one per function group, or template-level vs site-level resources). Each state refresh would only hit a subset of resources. This is the proper fix.

2. **Targeted refreshes**: For manual command-line runs, refresh only the resources you're changing:

```bash
terraform plan -refresh=true -parallelism=1 -target=mso_schema_template_bd_subnet.bd_fmwr_svr_subnet
```

3. **Upgrade the MSO provider**: Later versions of CiscoDevNet/mso may handle API sessions better. Check for updates periodically.

4. **Remove `-refresh=false` once split**: After splitting into smaller modules, each state refresh will be manageable and `-refresh=false` can be removed.

### Targeted Operations

When only a few resources need to be created or changed, use `-target` to avoid touching the full state:

```bash
nohup terraform apply -parallelism=1 -auto-approve -refresh=false \
  -target=mso_schema_template_bd_subnet.bd_example_subnet \
  > apply_output.log 2>&1 &
```

### Periodic Full Refresh

To verify state matches NDO (e.g., after manual changes or before a major change), run a full refresh during off-hours:

```bash
nohup terraform plan -parallelism=1 > refresh_output.log 2>&1 &
```

Use `-parallelism=1` for full refreshes to minimize NDO API load. Expect intermittent auth errors -- retry if needed.

---

## IPv6 Address Migration (Feb 2026)

### What Changed

All BD subnet gateway IPs were migrated from short-form IPv6 (e.g., `e300::1/64`) to full-prefix form (e.g., `2609:efff:b33b:e300::1/64`). This was done on the remote server first, then the local copy was updated to match.

### State Drift During Migration

A `terraform apply` during the migration was interrupted by an SSH disconnect. This caused three resources to be created on NDO but not saved to Terraform state:

1. `mso_schema_template_bd_subnet.bd_fmwr_svr_subnet` -- BD-FMWR-SVR subnet
2. `mso_schema_template_bd_subnet.bd_nms_subnet` -- BD-NMS subnet
3. `mso_schema_site_anp_epg_domain.epg_fmwr_svr_domain_k` -- PhysDom_ACI_IPv6 on EPG-FMWR-SVR (AEDCK)

**Resolution for #1 and #3**: Deleted the objects from NDO, then ran a targeted apply:

```bash
nohup terraform apply -parallelism=1 -auto-approve -refresh=false \
  -target=mso_schema_template_bd_subnet.bd_fmwr_svr_subnet \
  -target=mso_schema_site_anp_epg_domain.epg_fmwr_svr_domain_k \
  > apply_output.log 2>&1 &
```

**Resolution for #2 (BD-NMS)**: Hit a CiscoDevNet/mso provider bug (see below). Subnet was created manually in NDO and the Terraform resource was commented out.

### CiscoDevNet/mso Provider Bug: BD-NMS Subnet

The BD-NMS subnet (`2609:efff:b33b:0100::1/64`) consistently fails with:

```
Error: Provider produced inconsistent result after apply
root object was present, but now absent
```

**Root cause**: The `0100` hex group in the IPv6 address has a leading zero. NDO normalizes it differently than what the MSO provider expects on read-back. The provider creates the subnet successfully but cannot match it when reading back, causing the error. All other subnets have 4-significant-digit hex groups (e.g., `1500`, `e300`) and are unaffected.

**Workaround**: The `bd_nms_subnet` resource is commented out in `bds_epgs.tf`. The subnet is managed manually in NDO until the provider is fixed. The resource block is preserved with a comment explaining the bug.

### Importing Existing Resources

If resources exist on NDO but not in Terraform state, use `terraform import`:

```bash
terraform state show data.mso_schema.existing    # get schema_id
terraform state show data.mso_site.aedck          # get site_id

terraform import mso_schema_template_bd_subnet.bd_example_subnet \
  "<schema_id>/template/L2_Stretched/bd/BD-EXAMPLE/subnet/<ip>"

terraform import mso_schema_site_anp_epg_domain.epg_example_domain_k \
  "<schema_id>/site/<site_id>/template/L2_Stretched/anp/AppProf-RCC/epg/EPG-EXAMPLE/domain/physicalDomain/PhysDom_ACI_IPv6"
```

**Note**: `terraform import` can also hit NDO API timeouts. If it fails with "plugin did not respond" or auth errors, delete the object from NDO and use a targeted apply instead.

---

## Troubleshooting

### "Username must be provided for the MSO/ACI provider"

The pipeline is not receiving the credential variables. Check:
1. Variables are named exactly `TF_VAR_ndo_username`, `TF_VAR_ndo_password`, etc. (case-sensitive, lowercase after prefix)
2. Variables are **not** scoped to a specific environment (should be `All (default)`)
3. If variables are **Protected**, the `main` branch must also be protected in Settings > Repository > Protected Branches

### "Invalid username or password"

This error is intermittent and usually caused by the NDO API session timing out during large plan operations. The `bds_epgs.tf` file contains ~4200 lines of resources, requiring hundreds of API calls during state refresh.

Mitigations:
- Use `-refresh=false` to skip state refresh entirely (primary fix)
- Use `-parallelism=3` (max safe value; higher causes timeouts)
- Use `-target=` to limit scope when only a few resources need changes
- If it fails, re-run -- it often passes on retry
- Drop to `-parallelism=1` for stubborn failures

### "Provider produced inconsistent result after apply"

The MSO provider created a resource on NDO but failed to read it back. This is a provider bug affecting IPv6 addresses with leading-zero hex groups (e.g., `0100`). See "CiscoDevNet/mso Provider Bug" above.

If this happens:
1. Check NDO GUI -- the resource was likely created successfully
2. Comment out the resource in `.tf` and manage it manually in NDO
3. Do NOT keep retrying -- it will create duplicates on NDO

### "request cancelled: grpcprovider" / "plugin did not respond"

The Terraform provider crashed or timed out waiting for NDO. Caused by too many concurrent API calls during state refresh.

Fix: Use `-refresh=false` and/or `-target=` to reduce API load.

### "must have unique subnets" / "must be unique"

A resource exists on NDO but not in Terraform state. This happens when a previous apply created the resource but state wasn't saved (e.g., SSH disconnect, timeout).

Options:
1. **Import** the existing resource into state (see "Importing Existing Resources")
2. **Delete** the resource from NDO and let Terraform recreate it
3. If import fails due to API timeouts, option 2 is more reliable

### "Error acquiring the state lock"

Caused by a previous operation that didn't finish cleanly. Fix with:

```bash
terraform force-unlock <LOCK_ID>
```

The Lock ID is shown in the error message. Run any terraform command (e.g., `terraform plan`) to trigger the error and see the lock ID.

### "HTTP remote state endpoint requires auth"

The `CI_JOB_TOKEN` lacks permission for state locking. This is why we use `TF_STATE_TOKEN` (a Personal Access Token with `api` scope) instead.

### Pipeline YAML Parse Errors

The remote GitLab uses a **shell runner** (`aci-automation-runner` on `apckw059aau0096`), not a Docker runner. This affects what YAML syntax works. Several issues were encountered and resolved while setting up the pipeline:

**"jobs git_ssl_no_verify config should implement the script:, run:, or trigger: keyword"**

This happened because GitLab was interpreting the global `variables:` block entries as job names. The root cause was the expanded variable syntax (`description:`, `value:` sub-keys) which isn't supported on all GitLab versions. The fix was to use simple `KEY: "value"` pairs or remove the global `variables:` block entirely and use `TF_VAR_` environment variables set in GitLab CI/CD Settings instead.

**"jobs validate config should implement the script:, run:, or trigger: keyword"**

The YAML structure was syntactically correct, but invisible characters (tabs, BOM markers, or non-breaking spaces) were introduced during copy-paste or email transfer. YAML requires exactly **2 spaces** per indent level -- tabs will silently break parsing.

**Rules for this shell runner environment:**

1. **No `image:` directive** -- that's for Docker runners only; the shell runner ignores it or errors
2. **No `---` document start marker** -- caused parse failures on this GitLab instance
3. **No expanded variable syntax** -- don't use `description:` or `value:` sub-keys under `variables:`; use simple `KEY: "value"` pairs
4. **Use `only:` instead of `rules:`** -- `rules:` with `changes:` caused issues; `only:` is simpler and universally supported
5. **No YAML anchors or multiline blocks** -- keep syntax flat and simple
6. **Avoid copy-paste from email or rich text** -- invisible formatting characters break YAML. If editing remotely, use the **GitLab Pipeline Editor** (Build > Pipeline editor) which validates in real-time, or paste into `vi` on the server to strip hidden characters
7. **Always use 2 spaces for indentation, never tabs** -- YAML treats tabs as errors but some parsers silently mangle them

**If the YAML won't validate**, start from this minimal working template and add jobs one at a time:

```yaml
stages:
  - plan

plan:
  stage: plan
  script:
    - echo "test"
```

### Runner Offline

The runner is installed in the user's home directory at `~/gitlab-runner/gitlab-runner` and runs as a background process (no sudo access, no systemd user services on this RHEL 8 host). If the runner shows as offline in GitLab:

```bash
# SSH into the runner host
ssh apckw059aau0096

# Kill any existing (possibly stuck) runner processes
pkill gitlab-runner

# Start a fresh runner in the background
nohup ~/gitlab-runner/gitlab-runner run &

# Verify only one is running
ps aux | grep gitlab-runner
```

The runner should appear online in GitLab within 30 seconds. You'll need to re-run this any time the server reboots or the process dies, since user-level systemd services are disabled on this host.

### Plan File Argument Order

When applying a saved plan file, it must be the **last argument**:

```bash
# Correct
terraform apply -input=false -auto-approve -parallelism=3 plan.tfplan

# Wrong (causes "too many command line arguments")
terraform apply -input=false -auto-approve plan.tfplan -parallelism=3
```

---

## Manual Command-Line Execution (SSH Sessions)

When running Terraform manually over SSH, long-running plan/apply operations can be killed by SSH session timeouts or server-side idle disconnects. Use `nohup` to run Terraform in the background so it survives a dropped connection.

### Plan

```bash
nohup terraform plan -parallelism=3 -refresh=false -out=plan.tfplan > plan_output.log 2>&1 &
tail -f plan_output.log
```

### Apply

```bash
nohup terraform apply -parallelism=3 "plan.tfplan" > apply_output.log 2>&1 &
tail -f apply_output.log
```

### Direct Apply (without saved plan)

```bash
nohup terraform apply -parallelism=1 -auto-approve -refresh=false > apply_output.log 2>&1 &
tail -f apply_output.log
```

### Targeted Apply (specific resources only)

```bash
nohup terraform apply -parallelism=1 -auto-approve -refresh=false \
  -target=mso_schema_template_bd_subnet.bd_example_subnet \
  > apply_output.log 2>&1 &
tail -f apply_output.log
```

`tail -f` lets you watch progress in real time. If your SSH session drops, reconnect and run `tail -f <log>` again -- the Terraform process continues in the background regardless.

### Why `-parallelism=3`

The NDO API throttles concurrent requests. At higher parallelism values (5+), the API returns authentication errors mid-run because session tokens expire or get invalidated under load. `-parallelism=3` is the highest reliable value for this environment. Do not increase it unless the NDO API throttling behavior changes.

### Checking on a Backgrounded Job

```bash
# Check if Terraform is still running
jobs -l
# or
ps aux | grep terraform

# Resume watching output
tail -f plan_output.log
tail -f apply_output.log
```

---

## Pipeline Flow

```
git push to main
    |
    v
[validate] --> terraform fmt -check (allowed to fail)
    |
    v
[plan] --> terraform init (with backend config)
       --> terraform plan -out=plan.tfplan -parallelism=3 -refresh=false
       --> terraform show plan.tfplan > plan.txt
       --> saves plan.tfplan and plan.txt as artifacts
    |
    v
[deploy] --> terraform init (with backend config)
         --> terraform apply plan.tfplan -parallelism=3
         --> runs automatically on main branch
    
[destroy] --> manual trigger only
          --> terraform plan -destroy
          --> terraform apply destroy plan
```

---

## Lab vs Production Environments

### Overview

The codebase supports both a lab (local Mac) and production (remote server / pipeline) environment using a single set of `.tf` files. Environment-specific differences are handled through Terraform variables and `.tfvars` files.

### What Differs Between Environments

| Setting | Lab | Production |
|---|---|---|
| VRF Template Name | `VRF_Template` | `UpgradeTemplate1` |
| MSO Provider `domain` | `"local"` | omitted (`null`) |
| MSO Provider `platform` | `"nd"` | omitted (`null`) |
| NDO URL | Lab NDO URL | Production NDO URL |
| Credentials | Lab credentials | Production credentials (via `TF_VAR_` env vars) |
| State Backend | Local (or separate lab backend) | GitLab HTTP backend |

### What Stays the Same

- All BD/EPG/ANP resource names
- All IPv6 subnet addresses (`2609:efff:b33b:...`)
- All `L2_Stretched` template references
- All site names (AEDCG, AEDCK)
- The `bd_nms_subnet` workaround (commented out in both)

### Files

- **`variables.tf`**: Defines `vrf_template_name`, `mso_domain`, and `mso_platform` variables. `mso_domain` and `mso_platform` default to `null` (production behavior).
- **`main.tf`**: Provider block uses `var.mso_domain` and `var.mso_platform` instead of hardcoded values.
- **`bds_epgs.tf`**: All VRF template references use `var.vrf_template_name` instead of a hardcoded string.
- **`lab.tfvars`**: Lab-specific values (template name, domain, platform, credentials).
- **`prod.tfvars`**: Production-specific values (template name, credentials). `mso_domain` and `mso_platform` are omitted so they default to `null`.

Both `.tfvars` files are excluded from git by the `*.tfvars` pattern in `.gitignore`.

### Running Lab (Local Mac)

```bash
terraform init
terraform plan -var-file="lab.tfvars" -parallelism=3 -out=plan.tfplan
terraform apply "plan.tfplan"
```

The lab environment uses a local state file by default (no remote backend). If you need a separate remote backend for lab, configure it via `-backend-config` flags during `terraform init`.

### Running Production (Remote Server)

```bash
terraform init -backend-config="address=..." -backend-config="..."
nohup terraform plan -var-file="prod.tfvars" -parallelism=3 -refresh=false -out=plan.tfplan > plan_output.log 2>&1 &
tail -f plan_output.log
nohup terraform apply -parallelism=3 "plan.tfplan" > apply_output.log 2>&1 &
tail -f apply_output.log
```

### Running Production (Pipeline)

The `.gitlab-ci.yml` sets `TF_VAR_vrf_template_name: "UpgradeTemplate1"` as a pipeline variable. Other credentials (`TF_VAR_ndo_username`, `TF_VAR_ndo_password`, `TF_VAR_ndo_url`) are configured in GitLab CI/CD Settings. Since `mso_domain` and `mso_platform` default to `null`, no additional pipeline variables are needed for them.

### Important: Separate State Files

Lab and production must use **separate Terraform state files**. They manage different NDO instances with different configurations. Never point lab at the production state backend or vice versa.

---

## Key Decisions and Rationale

| Decision | Rationale |
|---|---|
| `TF_VAR_` prefix on CI/CD variables | Terraform reads them directly; avoids shell `export` that mangled special characters in passwords |
| Personal Access Token for state backend | `CI_JOB_TOKEN` lacked state locking permissions on this GitLab instance |
| `-parallelism=3` | Highest safe value; higher values cause NDO API session timeouts with large resource counts |
| `-refresh=false` on plan | Skips state refresh to prevent NDO API overload; drift detection done manually during off-hours |
| GitLab HTTP backend for state | Shares state between command-line and pipeline; prevents "already exists" errors |
| Single long `terraform init` lines | Avoids YAML multiline/anchor syntax that caused parse errors on the remote GitLab |
| `allow_failure: true` on validate | Formatting issues shouldn't block the pipeline |
| BD-NMS subnet commented out | CiscoDevNet/mso provider bug with IPv6 leading-zero hex groups; managed manually in NDO |
| Full IPv6 prefix in `.tf` files | Addresses use `2609:efff:b33b:[func]00::1/64` format to match what NDO stores and returns |
| `nohup` for manual SSH runs | Prevents SSH timeouts from killing long-running Terraform operations |
| `retry: max: 2` on plan/deploy | NDO auth errors are intermittent; auto-retry usually succeeds on second attempt |
| `.tfvars` for lab/prod | Single codebase with environment-specific values in `lab.tfvars` and `prod.tfvars`; avoids maintaining two copies of `bds_epgs.tf` |
| `var.vrf_template_name` | Replaces hardcoded template name so lab (`VRF_Template`) and production (`UpgradeTemplate1`) share the same `.tf` files |


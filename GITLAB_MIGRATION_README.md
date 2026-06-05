# Local GitLab Migration Guide

## Overview

Three project repositories were migrated to a local GitLab CE instance running at `http://localhost:8080` to keep customer infrastructure data off public repositories. Each repo was cleaned up, restructured, and given a CI/CD pipeline.

---

## GitLab Projects

| Local Repo Path | GitLab Project | Purpose |
|---|---|---|
| `~/ndo_terraform_nac` | [root/ndo_terraform](http://localhost:8080/root/ndo_terraform) | NDO/NAC production configs, site data, Robot Framework tests |
| `~/Documents/terraform_redesign_esg` | [root/terraform_redesign_esg](http://localhost:8080/root/terraform_redesign_esg) | ACI redesign (VMM/NAC) + NDO Terraform BD/EPG definitions |
| `~/Documents/terraform_redesign/n5k_replacement` | [root/n5k_replacement](http://localhost:8080/root/n5k_replacement) | N5K to ACI leaf replacement (LAB + PRODUCTION) |

---

## Git Remote Configuration

Each repo has both the original remote and the local GitLab remote:

```
# ndo_terraform_nac
origin        → http://localhost:8080/Administrator/ndo_terraform.git
local-gitlab  → http://localhost:8080/root/ndo_terraform.git        ← use this one

# terraform_redesign_esg
origin        → git@github.com:johngbarberctr/terraform_redesign_esg.git  (old GitHub)
gitlab        → http://localhost:8080/root/terraform_redesign_esg.git      ← use this one

# n5k_replacement
origin        → https://github.com/johbarbe/n5k_replacement.git   (old GitHub)
gitlab        → http://localhost:8080/root/n5k_replacement.git     ← use this one
```

### Day-to-day git push

```bash
# Push to local GitLab (not GitHub)
git push gitlab main

# For ndo_terraform_nac, use:
git push local-gitlab main
```

---

## Repository Structure

### root/ndo_terraform (ndo_terraform_nac)

```
├── .ci/                    # CI helper scripts (GitLab comments, Webex notifications)
├── .gitlab-ci.yml          # CI/CD pipeline (validate → plan → deploy → test → notify)
├── 136.215.4.96/           # PRODUCTION IPv6 RCC workspace
│   ├── bds_epgs.tf
│   ├── l3outs_ndo.tf
│   ├── main.tf
│   └── variables.tf
├── data/
│   ├── ndo/                # NDO schemas and NAC configs
│   │   ├── ndo.nac.yaml
│   │   └── schema_AFRICOM.nac.yaml
│   └── sites/              # Per-site APIC configs
│       ├── primary/
│       ├── site_g/
│       └── site_k/
├── schemas/                # Validation schemas (apic.yaml, ndo.yaml)
├── scripts/                # Utilities (ndo_to_nac_converter.py, run_tests.sh)
├── tests/                  # Robot Framework tests and Jinja filters
├── workspaces/             # Terraform workspaces per site
│   ├── primary/main.tf
│   ├── site_g/main.tf
│   └── site_k/main.tf
└── main.tf                 # Root Terraform config (NAC-NDO module)
```

### root/terraform_redesign_esg

```
├── .gitlab-ci.yml          # CI/CD pipeline (separate jobs for NDO + ACI)
├── aci-redesign/
│   ├── apic-vmware/        # ACI VMM domain Terraform (NAC-ACI module)
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars.example
│   └── data/
│       ├── blueprints/         # Blueprint NAC YAML definitions
│       ├── nac-aci-shared/     # Cross-fabric YAML (tenant, BDs, EPGs, ESGs)
│       ├── nac-aci-site1/      # Site1-only access/fabric policies
│       └── nac-aci-site1-rendered/  # gitignored; vmm-domain.nac.yaml output
├── ndo-terraform/
│   ├── bds_epgs.tf         # NDO BD/EPG definitions (~4200 lines)
│   ├── main.tf             # MSO/ACI providers
│   ├── variables.tf
│   └── tf-modules/nac-ndo/ # Local copy of NAC-NDO module
├── data/
│   ├── blueprints/         # Top-level blueprint configs
│   └── excluded/           # Staged migration phase configs
├── docs/                   # Architecture docs, deployment guides, reports
└── scripts/                # Python utilities (bindings, analysis, backups)
```

### root/n5k_replacement

```
├── .gitlab-ci.yml          # CI/CD pipeline
├── providers.tf            # MSO provider config
├── variables.tf            # All variable definitions
├── versions.tf             # Required provider versions
├── schemas_and_epgs.tf     # Schema/EPG Terraform definitions
├── fabric_policies_ansible.tf
├── outputs.tf
├── Snake/
│   ├── LAB/                # LAB environment
│   │   ├── N5K/            # N5K migration tooling
│   │   └── aci-lf-rplc/   # ACI leaf replacement tooling
│   └── PRODUCTION/         # PRODUCTION environment
│       ├── N5K/            # N5K migration tooling
│       └── aci-lf-rplc/   # ACI leaf replacement tooling
└── ansible/                # Ansible playbooks for data processing
```

---

## Production Workspace

The VS Code workspace file `ACI_PRODUCTION.code-workspace` references production paths across two repos:

| Workspace Folder | Repo | Path |
|---|---|---|
| PROD - IPv6 RCC (136.215.4.96) | root/ndo_terraform | `136.215.4.96/` |
| PROD - N5K Migration & Leaf Replacement | root/n5k_replacement | `Snake/PRODUCTION/` |

---

## CI/CD Pipelines

### Pipeline Architecture

All three repos use GitLab CI/CD with the `danischm/nac:0.2.0` Docker image, which includes Terraform, NAC tools, and Python.

**Common pipeline stages:**

```
validate → plan → deploy → (destroy - manual)
```

- **validate**: `terraform fmt -check` and (for ndo_terraform) `nac-validate`
- **plan**: `terraform init` + `terraform plan`, saves plan as artifact
- **deploy**: `terraform apply` using the saved plan (only on `main` branch)
- **destroy**: manual trigger only, as a safety measure

### Terraform State

All pipelines store state in the GitLab HTTP backend (built into GitLab CE):

```
GitLab → Settings → Infrastructure → Terraform states
```

Each sub-project gets its own state file:
- `ndo_terraform`: `tfstate` (main) + `tfstate-ipv6` (IPv6)
- `terraform_redesign_esg`: `ndo-terraform` + `aci-redesign`
- `n5k_replacement`: `n5k-replacement`

### Required CI/CD Variables

Configure these in each project under **Settings → CI/CD → Variables**:

#### root/ndo_terraform

| Variable | Value | Masked | Protected |
|---|---|---|---|
| `MSO_USERNAME` | NDO admin username | No | Yes |
| `MSO_PASSWORD` | NDO admin password | Yes | Yes |
| `MSO_URL` | NDO URL (e.g., `https://10.196.209.170`) | No | Yes |
| `GITLAB_TOKEN` | Personal access token with `api` scope | Yes | No |
| `TF_HTTP_USERNAME` | GitLab username (e.g., `root`) | No | No |
| `TF_HTTP_PASSWORD` | GitLab access token | Yes | No |

#### root/terraform_redesign_esg

| Variable | Value | Masked | Protected |
|---|---|---|---|
| `NDO_USERNAME` | NDO admin username | No | Yes |
| `NDO_PASSWORD` | NDO admin password | Yes | Yes |
| `NDO_URL` | NDO URL | No | Yes |
| `APIC_USERNAME` | APIC admin username | No | Yes |
| `APIC_PASSWORD` | APIC admin password | Yes | Yes |
| `APIC_URL` | APIC URL | No | Yes |
| `GITLAB_TOKEN` | Personal access token | Yes | No |
| `TF_HTTP_USERNAME` | GitLab username | No | No |
| `TF_HTTP_PASSWORD` | GitLab access token | Yes | No |

#### root/n5k_replacement

| Variable | Value | Masked | Protected |
|---|---|---|---|
| `NDO_HOST` | NDO hostname or IP (without `https://`) | No | Yes |
| `NDO_USERNAME` | NDO admin username | No | Yes |
| `NDO_PASSWORD` | NDO admin password | Yes | Yes |
| `GITLAB_TOKEN` | Personal access token | Yes | No |
| `TF_HTTP_USERNAME` | GitLab username | No | No |
| `TF_HTTP_PASSWORD` | GitLab access token | Yes | No |

### Running a Pipeline

**Automatic triggers:**
- Pipelines run automatically on push to `main` or on merge requests
- `terraform_redesign_esg` uses change-based rules — only the affected sub-project's jobs run (e.g., changing `aci-redesign/` only triggers ACI jobs)

**Manual triggers:**
1. Go to the project in GitLab → **Build → Pipelines**
2. Click **Run pipeline**
3. Select the branch (`main`)
4. Click **Run pipeline**

**Running destroy (teardown):**
1. Go to **Build → Pipelines** → find the latest pipeline
2. The destroy job will show as a manual action (play button)
3. Click the play button to trigger it

### Merge Request Workflow

For a safe change workflow:
1. Create a feature branch: `git checkout -b feature/my-change`
2. Make changes, commit, push: `git push -u gitlab feature/my-change`
3. Create a merge request in GitLab (link shown in push output)
4. Pipeline runs `validate` + `plan` — review the plan in the MR
5. Merge to `main` — triggers `deploy` automatically

---

## Starting and Stopping GitLab

GitLab runs as a Docker container named `gitlab-ce-podman`.

```bash
# Start GitLab
docker start gitlab-ce-podman

# Stop GitLab
docker stop gitlab-ce-podman

# Check status
docker ps --filter name=gitlab

# View logs (useful during startup, takes 2-3 minutes)
docker logs -f gitlab-ce-podman
```

**Access:** http://localhost:8080
**SSH:** Port 2222
**HTTPS:** Port 8443

---

## Sensitive Files

The following file patterns are excluded from all repos via `.gitignore`:

```
*.tfvars / *.tfvars.json    # Terraform variables (contain credentials)
*.tfstate / *.tfstate.*     # Terraform state (contains infrastructure details)
vault.yml / vault_pass.txt  # Ansible vault files
secrets.yml                 # Ansible secrets
.env                        # Environment variables
.vault_pass                 # Vault password files
```

These files exist only on your local machine. Credentials for CI/CD are stored as GitLab CI/CD variables (masked and protected).

**Important:** The `n5k_replacement` repo has an NDO password (`cisco!123`) in its git history from when `terraform.tfvars` was previously tracked. This was removed from tracking but remains in history. Since the repo is on your private local GitLab, this is acceptable for now. If you ever move to a public repo, run `git filter-repo` to purge it and rotate the password.

---

## GitLab API Token

A personal access token was created for the `root` user:

- **Token:** `glpat-automation2026`
- **Scopes:** `api`, `read_repository`, `write_repository`
- **Expires:** 1 year from creation

Use this token for API calls, CI/CD variable `TF_HTTP_PASSWORD`, and `GITLAB_TOKEN`:

```bash
# Example: list projects
curl -s -H "PRIVATE-TOKEN: glpat-automation2026" http://localhost:8080/api/v4/projects | python3 -m json.tool
```

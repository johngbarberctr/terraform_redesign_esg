# Cisco ACI Infrastructure as Code — `terraform-esg`

> **Looking for the deployment runbook?** → **[`README_LAB.md`](README_LAB.md)**
>
> That file is the canonical 7-phase end-to-end procedure for bringing the
> lab up from scratch, including the dependency on the sibling repo
> `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/`. Production cutover walks the same
> phase order; per-stack deltas are in each stack's own README.

This file (the repo root README) covers what the repo *is*, GitLab CI/runner
setup, and where to find everything else. It deliberately does **not**
duplicate the deployment runbook.

---

## Security warning

**DO NOT COMMIT CREDENTIALS TO THIS REPOSITORY.** All `.tfvars`, `.tfstate*`,
`vault.yml`, `vault_pass.txt`, `.env`, and rendered VMM YAML files are
excluded via `.gitignore`. Each Terraform root validates this and the
`validate-aci` CI stage runs `.gitlab/ci-secret-scan.sh` to fail any
pipeline that contains a plaintext credential in tracked YAML.

> All IP addresses, URLs, hostnames, usernames, and passwords shown in this
> repo's READMEs are **placeholders or lab values**. Replace them with the
> real values for your environment from the per-stack `terraform.tfvars`
> files or GitLab masked CI variables. Lab IPs rotate when dCloud rebuilds.

---

## Repository contents

This repo contains **four Terraform roots** plus shared scripts and docs.
The fifth root in the deployment order — `sac-johbarbe-AFRICOM-terraform-nac-ndo/` — lives
in a **sibling repo** at `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/`.

| Path | Terraform root? | What it owns | Reference |
|------|-----------------|--------------|-----------|
| `aci-redesign/apic-vmware/` | yes (lab APIC) | Per-fabric APIC access policies, MCP, VMware VMM domains for Kelley and Del-Din | [`aci-redesign/apic-vmware/README.md`](aci-redesign/apic-vmware/README.md) (+ [`README_LAB.md`](aci-redesign/apic-vmware/README_LAB.md)) |
| `aci-redesign/apic-vmware-prod/` | yes (prod APIC) | Same shape as `apic-vmware/`, but Design A (UCS-FI) and prod credentials, separate state | [`aci-redesign/apic-vmware-prod/README.md`](aci-redesign/apic-vmware-prod/README.md) |
| `aci-redesign/ndo/` | yes (lab NDO redesign) | Schema `AFRICOM-V2`, single template `Tenant_EUR_V2` (2 VRFs, 39 BDs/EPGs, 2 contracts; all tenant-scoped objects suffixed `-V2` to coexist with the legacy `AFRICOM` schema in tenant `EUR`) | [`aci-redesign/ndo/README.md`](aci-redesign/ndo/README.md) (+ [`README_LAB.md`](aci-redesign/ndo/README_LAB.md)) |
| `ndo-terraform-ipv6/` | yes (IPv6 RCC layer) | `AppProf-RCC` ANP + 39 IPv6 EPGs + L3Outs into existing `L2_Stretched` template | [`ndo-terraform-ipv6/README.md`](ndo-terraform-ipv6/README.md) (+ [`README_LAB.md`](ndo-terraform-ipv6/README_LAB.md)) |
| `aci-redesign/scripts/` | no (Python tools) | Bindings push helpers (`dump_bindings.py`, `deploy_bindings.py`, `generate_fi_bindings.py`) | [`aci-redesign/scripts/README.md`](aci-redesign/scripts/README.md) |
| `aci-redesign/data/` | no (NAC YAML inputs) | Per-fabric YAML consumed by the four Terraform roots above | [`aci-redesign/data/_archive/README.md`](aci-redesign/data/_archive/README.md), [`nac-aci-shared/README.md`](aci-redesign/data/nac-aci-shared/README.md) |
| `aci-redesign/` | n/a | Design rationale (2-VRF model, BD/EPG consolidation) | [`aci-redesign/DESIGN.md`](aci-redesign/DESIGN.md) |
| `docs/` | no | Architecture diagrams, reports, deployment guides | [`docs/README.md`](docs/README.md) |
| `data/` | no | Legacy NAC YAML and archived migration phase configs | — |

The sibling repo is the foundational layer:

| Sibling repo | What it owns |
|---|---|
| `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/` (separate git repo) | Tenant `EUR`, schema `AFRICOM` with 5 templates (`VRF_Template`, `L2_Stretched`, `L2_Non-Stretched`, `Kelley-Specific_Only`, `Del-Din-Specific_Only`), 11 prod VRFs, 266 BDs, 265 EPGs, 13 L3Outs, 812 VPC static-port bindings |

That stack creates the `Any` filter under `AFRICOM/VRF_Template` that
`aci-redesign/ndo/`'s schema cross-references. **It must be deployed
first** — the runbook in [`README_LAB.md`](README_LAB.md) makes this Phase 1.

---

## Cross-cutting reference docs

| File | When to read it |
|------|-----------------|
| [`README_LAB.md`](README_LAB.md) | **Start here** — end-to-end deployment runbook (lab) |
| [`PROJECT_MAP.md`](PROJECT_MAP.md) | Server / hostname / file-path / CI cross-reference |
| [`PROJECTS_LISTING.md`](PROJECTS_LISTING.md) | Inventory of every Mac project + git remotes |
| [`aci-redesign/DESIGN.md`](aci-redesign/DESIGN.md) | 2-VRF redesign rationale, BD/EPG consolidation, ESG plan |
| [`docs/README.md`](docs/README.md) | Architecture diagrams + design reports |

---

## Prerequisites

- **Terraform** ≥ 1.5 (pinned providers: `mso ~> 1.6`, `aci 2.18.0`)
- **Python** ≥ 3.7 with `requests`, `urllib3`, `PyYAML`
- **Git** access to the GitLab repo
- Network connectivity to NDO and/or APIC

### One-time setup (lab — local Mac)

```bash
# Clone the repo
git clone http://localhost:8080/root/terraform_redesign_esg.git
cd terraform_redesign_esg

# Python venv (one-time). Canonical name on this laptop is ~/dc_redesign.
# Activate it before every session (or after every shell restart) before
# running any of the scripts in aci-redesign/scripts/ or ndo-terraform-ipv6/.
python3 -m venv ~/dc_redesign
source ~/dc_redesign/bin/activate
pip install requests urllib3 PyYAML
```

Then follow [`README_LAB.md`](README_LAB.md) Phase 1 onwards.

### One-time setup (production — RHEL 8 server via SSH)

```bash
# Clone the repo
git clone https://sync.git.mil/john.g.barber.ctr/my-new-ipv6-project.git
cd my-new-ipv6-project

# Python venv (one-time). On the prod RHEL 8 host the venv is named ~/ansvenv
# (NOT ~/dc_redesign, which is the laptop name). Activate it before running any
# of the scripts in aci-redesign/scripts/ or ndo-terraform-ipv6/.
python3 -m venv ~/ansvenv
source ~/ansvenv/bin/activate
pip install requests urllib3 PyYAML
```

Production cutover follows the same phase order as lab. Per-stack production
deltas live in each stack's `README.md` (look for "Lab vs production"
sections); the multi-team coordinated cutover is in
[`aci-redesign/README.md`](aci-redesign/README.md).

---

## GitLab project & remotes

| Detail | Value |
|---|---|
| Production GitLab | `https://sync.git.mil` |
| Lab GitLab | `http://localhost:8080` |
| Project ID (prod) | `38767` |
| Runner | Shell executor on `apckw059aau0096` (`aci-automation-runner`) |
| Git remote (prod) | `sync.git.mil/john.g.barber.ctr/my-new-ipv6-project` |
| Git remote (lab) | `localhost:8080/root/terraform_redesign_esg` |

### Pushing changes

```bash
git push gitlab main    # remote name is 'gitlab' for both lab and prod
```

---

## CI/CD pipeline

Each Terraform root in this repo owns a per-project `.gitlab-ci.yml` with
the same 3-stage shape: **`validate → plan → apply (manual)`**. The root
`terraform-esg/.gitlab-ci.yml` is a thin orchestrator that defines shared
CI/CD variables, the `.tf-job` template, and `include:`s each per-project
file.

| Project | Per-project CI file | Apply targets | Manual NDO-UI step after apply? | Live in CI today? |
|---------|---------------------|---------------|--------------------------------|------|
| `aci-redesign/apic-vmware/` | [`aci-redesign/apic-vmware/.gitlab-ci.yml`](aci-redesign/apic-vmware/.gitlab-ci.yml) | Lab APIC fabrics (Kelley + Del-Din) | No — APIC has it | Dormant — file untracked; activate per [Enabling and disabling per-project pipelines](#enabling-and-disabling-per-project-pipelines) |
| `aci-redesign/apic-vmware-prod/` | [`aci-redesign/apic-vmware-prod/.gitlab-ci.yml`](aci-redesign/apic-vmware-prod/.gitlab-ci.yml) | Prod APIC fabrics | No — APIC has it | Dormant — file untracked |
| `aci-redesign/ndo/` | [`aci-redesign/ndo/.gitlab-ci.yml`](aci-redesign/ndo/.gitlab-ci.yml) | NDO schema `AFRICOM-V2` | **Yes** — Deploy `Tenant_EUR_V2` to Kelley/Del-Din | **Yes** |
| `ndo-terraform-ipv6/` | [`ndo-terraform-ipv6/.gitlab-ci.yml`](ndo-terraform-ipv6/.gitlab-ci.yml) | NDO schema `AFRICOM / L2_Stretched` (extends) | **Yes** — Re-deploy `L2_Stretched` | **Yes** |

The sibling foundational stack lives in its own repo with its own root CI:

| Sibling repo | Per-project CI file | Apply targets | Manual NDO-UI step? |
|--------------|---------------------|---------------|---------------------|
| `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/` | `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/.gitlab-ci.yml` | NDO tenant `EUR` + schema `AFRICOM` (5 templates) | **Yes** — Deploy 5 templates in strict order |

### How to trigger a single-project pipeline

- **Auto** — push or open an MR that changes that project's directory (or
  the shared inputs it consumes, e.g. `aci-redesign/data/nac-ndo/` for
  the redesign NDO project). The `rules: changes:` in each per-project
  file scopes the pipeline to that project alone.
- **Manual** — GitLab UI → **Run pipeline** → set the `PROJECT` variable
  to one of: `apic-vmware`, `apic-vmware-prod`, `aci-redesign-ndo`,
  `ndo-terraform-ipv6`. Only that project's jobs queue up.

`apply` jobs are **always** `when: manual` regardless of how the
pipeline was triggered. No project ever auto-applies. After clicking
apply, you do the manual NDO-UI deploy step (where applicable, see
table above) — the apply job's tail prints the exact UI path to click.

### Enabling and disabling per-project pipelines

The umbrella's `include:` block uses `rules: exists:` so each per-project
pipeline only loads if its `.gitlab-ci.yml` is **present in the repo**:

```yaml
include:
  - local: aci-redesign/apic-vmware/.gitlab-ci.yml
    rules:
      - exists: [aci-redesign/apic-vmware/.gitlab-ci.yml]
  - local: aci-redesign/apic-vmware-prod/.gitlab-ci.yml
    rules:
      - exists: [aci-redesign/apic-vmware-prod/.gitlab-ci.yml]
  - local: aci-redesign/ndo/.gitlab-ci.yml
    rules:
      - exists: [aci-redesign/ndo/.gitlab-ci.yml]
  - local: ndo-terraform-ipv6/.gitlab-ci.yml
    rules:
      - exists: [ndo-terraform-ipv6/.gitlab-ci.yml]
```

To **enable** a project: keep its per-project `.gitlab-ci.yml` committed;
populate the project's required CI/CD variables; set up the GitLab HTTP
state slot (or migrate an existing local state into it — see each
project's README).

To **disable** a project (e.g. for a project that has CI definitions
written but is not yet operationally ready): `git rm` its
`.gitlab-ci.yml` and commit. The umbrella pipeline silently drops it
from the next pipeline run; everything else keeps working. Restore by
re-committing the file.

This is how `aci-redesign/apic-vmware/` and
`aci-redesign/apic-vmware-prod/` (lab and prod APIC roots, deferred for
now) sit dormant in the repo without breaking the umbrella pipeline.

### Required CI/CD variables (Settings → CI/CD → Variables)

These names are the **GitLab CI variable names** (set on the GitLab
project's variables page). The per-project `.gitlab-ci.yml` files map
them onto the `TF_VAR_*` variables Terraform expects.

| Variable | Purpose | Masked + Protected |
|----------|---------|--------------------|
| `NDO_USERNAME` / `NDO_URL` | NDO connection (used by `aci-redesign/ndo/` and `ndo-terraform-ipv6/`) | No |
| `NDO_PASSWORD` | NDO password | Yes |
| `KELLEY_APIC_URL` / `KELLEY_APIC_USERNAME` | Lab Kelley APIC | No |
| `KELLEY_APIC_PASSWORD` / `KELLEY_MCP_KEY` | Lab Kelley secrets | Yes |
| `DELDIN_APIC_URL` / `DELDIN_APIC_USERNAME` | Lab Del-Din APIC | No |
| `DELDIN_APIC_PASSWORD` / `DELDIN_MCP_KEY` | Lab Del-Din secrets | Yes |
| `KELLEY_APIC_URL_PROD` / `KELLEY_APIC_USERNAME_PROD` | Prod Kelley APIC (only in prod GitLab) | No |
| `KELLEY_APIC_PASSWORD_PROD` / `KELLEY_MCP_KEY_PROD` | Prod Kelley secrets | Yes |
| `DELDIN_APIC_URL_PROD` / `DELDIN_APIC_USERNAME_PROD` | Prod Del-Din APIC | No |
| `DELDIN_APIC_PASSWORD_PROD` / `DELDIN_MCP_KEY_PROD` | Prod Del-Din secrets | Yes |
| `VCENTER_HOSTNAME_IP` / `VCENTER_DATACENTER` / `VCENTER_DVS_VERSION` | vCenter (shared between lab/prod APIC roots; if prod has a different vCenter instance, add `_PROD` variants) | No |
| `VCENTER_USERNAME` / `VCENTER_PASSWORD` | vCenter creds | Yes |
| `GITLAB_TOKEN` | MR comments (optional) | Yes |
| `PROJECT` | Optional — set when manually running a pipeline to scope it to one project | No (run-time only) |

> **No `TF_HTTP_*` project variables required.** Each per-project file pins
> the HTTP state backend's credentials inside its `*-vars` anchor to
> `gitlab-ci-token` / `${CI_JOB_TOKEN}`. The CI job token is auto-minted
> per job, has read/write to that project's Terraform state, and is
> auto-revoked at job end. **No PAT to provision and no expiry to
> manage.** If you've previously set `TF_HTTP_USERNAME` /
> `TF_HTTP_PASSWORD` on the project, you can delete them — they are no
> longer used. The same applies to the sibling repo
> `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/`.

Sibling repo `sac-johbarbe-AFRICOM-terraform-nac-ndo/` has its own variable set
(`MSO_URL`, `MSO_USERNAME`, `MSO_PASSWORD`, `MSO_DOMAIN`) defined on that
repo's GitLab project. See [`~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/README.md` →
"GitLab CI/CD variables"](../sac-johbarbe-AFRICOM-terraform-nac-ndo/README.md#gitlab-cicd-variables).

#### Provisioning the lab variable set in one shot

There are two scripts in `scripts/` for this — pick the one that fits
your workflow:

**Interactive (recommended for first-time setup):**

```bash
./scripts/setup_gitlab_ci_variables_interactive.sh
```

Auto-discovers NDO/APIC URLs, usernames, and the lab NDO password from
your existing `terraform.tfvars` and `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/.env`
files. Auto-generates two distinct MCP keys (16 chars, APIC- and
GitLab-mask-compatible alphabet `[A-Za-z0-9+=]`, with at least one of
each character class). Silently prompts for what it can't discover:
the GitLab PAT, APIC admin password, and vCenter hostname / datacenter
/ user / password. Shows a no-values-leaked summary, asks for
confirmation, then provisions.

**Non-interactive (re-runs / CI / scripted):**

```bash
export GITLAB_TOKEN=glpat-...
export NDO_USERNAME=...
export NDO_PASSWORD=...
# ... etc., one export per variable
./scripts/setup_gitlab_ci_variables.sh
```

Each value comes from a same-named env var. Both scripts:

- contain no secrets
- never echo any value (only the variable name + flags)
- are idempotent (POST to create, PUT to update)
- target `root/terraform_redesign_esg` on `http://localhost:8080` by
  default — override with `GITLAB_URL` and `GITLAB_PROJECT`
- apply the masked/protected flags per the table above, **with one
  automatic downgrade**: GitLab's masked-variable validator requires
  values to be ≥ 8 chars and contain only `[A-Za-z0-9+/=@:.~-]`. If a
  value would otherwise be rejected (most often `VCENTER_PASSWORD =
  C1sco12345!` because of the `!`), the script logs a `warn` line and
  sets the variable with `masked=false`, keeping `protected=true`.
  Auto-generated MCP keys and real GitLab PATs always pass the check.

Re-run any time — only variables whose env var is set are touched.

#### Provisioning the `_PROD` APIC variables (production cutover)

`apic-vmware-prod/.gitlab-ci.yml` reads 8 `_PROD`-suffixed APIC variables
(`KELLEY_APIC_URL_PROD`, `KELLEY_APIC_USERNAME_PROD`,
`KELLEY_APIC_PASSWORD_PROD`, `KELLEY_MCP_KEY_PROD`, and the four matching
`DELDIN_*_PROD`). There are two patterns for populating them; both are
supported by the same scripts.

**Pattern A — separate production GitLab instance (recommended).**
Lab and prod CI live on different GitLab servers. Variable names are
identical on both servers — only the values differ. Re-run the lab
scripts against the production server:

```bash
GITLAB_URL=https://gitlab.prod.example.com \
GITLAB_PROJECT=team/terraform-esg \
  ./scripts/setup_gitlab_ci_variables_interactive.sh
```

**Pattern B — one GitLab project hosts both lab and prod CI.** Run the
lab pass first to seed the 18 lab variables, then add the 8 `_PROD`
APIC variables with `--prod`:

```bash
./scripts/setup_gitlab_ci_variables_interactive.sh           # lab pass (18 vars)
./scripts/setup_gitlab_ci_variables_interactive.sh --prod    # prod pass (8 *_PROD APIC vars)
```

`--prod` mode prompts for the prod APIC URLs and admin password, auto-
generates fresh prod MCP keys, and leaves `NDO_*`, `VCENTER_*`, and
`TF_HTTP_*` alone (the per-project CI files have no `_PROD` variant for
those — they're either shared with lab or already provisioned).

For scripted use the non-interactive variant accepts a `PROD=1` env
var that flips it into the same prod-only set:

```bash
PROD=1 \
KELLEY_APIC_URL_PROD=https://... KELLEY_APIC_USERNAME_PROD=admin \
KELLEY_APIC_PASSWORD_PROD='...' KELLEY_MCP_KEY_PROD='...' \
DELDIN_APIC_URL_PROD=https://... DELDIN_APIC_USERNAME_PROD=admin \
DELDIN_APIC_PASSWORD_PROD='...' DELDIN_MCP_KEY_PROD='...' \
GITLAB_TOKEN=... \
  ./scripts/setup_gitlab_ci_variables.sh
```

---

## GitLab runner

The runner is a user-local binary on a RHEL server (no sudo, no systemd).
There are **two runner servers**:

| Server | Hostname | Projects served |
|--------|----------|-----------------|
| `apckw059aau0096` | aci-automation-runner | this repo + `sac-johbarbe-AFRICOM-terraform-nac-ndo` |
| `APCKW059AAU0018` | — | `n5k`, `aci-lf-rplc` |

This repo's pipelines run on **`apckw059aau0096`**.

### Operate the runner

```bash
ssh apckw059aau0096
hostname                                         # confirm you're on the right server

find /home/john.g.barber.ctr -name "gitlab-runner" -type f 2>/dev/null
find /Viper                  -name "gitlab-runner" -type f 2>/dev/null

ps aux | grep gitlab-runner | grep -v grep       # is it running?

nohup ~/gitlab-runner/gitlab-runner run &        # start
pkill gitlab-runner && nohup ~/gitlab-runner/gitlab-runner run &   # restart
```

The runner shows online in GitLab within 30 seconds. It's a background
process — it dies on reboot. Auto-restart via crontab:

On `apckw059aau0096` (this repo + `sac-johbarbe-AFRICOM-terraform-nac-ndo`):

```bash
crontab -e
@reboot                       nohup /home/john.g.barber.ctr/gitlab-runner/gitlab-runner run &
*/5    * * * * pgrep -f "gitlab-runner run" > /dev/null || nohup /home/john.g.barber.ctr/gitlab-runner/gitlab-runner run &
```

On `APCKW059AAU0018` (`n5k`, `aci-lf-rplc`):

```bash
crontab -e
@reboot                       nohup /home/john.g.barber.ctr/gitlab-runner run &
*/5    * * * * pgrep -f "gitlab-runner run" > /dev/null || nohup /home/john.g.barber.ctr/gitlab-runner run &
```

### Lab vs production runner type

**Lab GitLab runs on a Docker executor.** Per-project CI files declare
`image: danischm/nac:0.2.0` (the Network as Code image with terraform,
jq, and terraform-docs pre-installed) and pipelines run inside that
container.

**Production GitLab runs on a shell executor.** It silently ignores
`image:`, runs job scripts directly on the runner host, and relies on
terraform/jq being installed under `/usr/bin/`. Each `.tf-job` template
in the orchestrator includes `before_script: export PATH="/usr/bin:$PATH"`
to keep the host PATH sane on the shell runner.

The same `.gitlab-ci.yml` files work on both — only the CI/CD variable
values (URLs, credentials, `*_PROD` vs unsuffixed) differ between the
lab and prod GitLab project settings.

### State backend (CI vs laptop)

Every Terraform root in this repo declares `backend "http" {}` so CI can
push state to the GitLab HTTP backend at
`${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/<state-name>`.
State names are project-unique (`aci-redesign-ndo`,
`ndo-terraform-ipv6`, etc.) so two pipelines can never collide on the
same state file or lock.

**For laptop runs** you opt out of the HTTP backend with a gitignored
`local_override.tf` next to the project's `main.tf`:

```bash
cat > local_override.tf <<'EOF'
terraform {
  backend "local" {}
}
EOF
terraform init        # picks up the override; uses local terraform.tfstate
```

The `*_override.tf` glob is in the repo root `.gitignore`, so this file
never reaches CI. Each project's `README_LAB.md` walks through this for
the new operator.

State backups created during migration go in `.local-state-backups/`
(also gitignored at the root). Don't commit state files — `*.tfstate*`
is gitignored too.

### Coding conventions for `.gitlab-ci.yml` files in this repo

1. Two-space indentation, no tabs.
2. Each per-project file scopes itself with `rules: changes:` and an
   `if: $PROJECT == "<name>"` clause for manual triggering.
3. `apply` jobs are always `when: manual`. No project auto-applies.
4. Sensitive `TF_VAR_*` get sourced from masked CI variables inside the
   per-job `variables:` block, never declared at the top level (so a
   leak in one project doesn't expose another).
5. The `.tf-job` template (defined in the root orchestrator) is extended
   by every per-project job to inherit `image:` and `before_script:`.
6. State backend addresses use `${GITLAB_API_URL}/projects/${CI_PROJECT_ID}/terraform/state/<state-name>`
   with a project-unique `<state-name>` so two projects can never collide
   on the same state file or lock.

---

## Related projects (other Mac repos)

| Project | GitLab repo | Purpose |
|---|---|---|
| `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/` | `root/ndo_terraform` | **Phase 1** of the deployment runbook in this repo's `README_LAB.md` — foundational NDO-NAC stack (tenant `EUR`, schema `AFRICOM`, 5 templates, 812 VPC bindings) |
| `~/DC/NXOS/n5k/` | `root/n5k_replacement` | N5K switch migration and ACI leaf replacement (separate workflow) |
| `~/DC/NXOS/n5k/Snake/{LAB,PRODUCTION}/aci-lf-rplc/` | sub-dirs of `n5k_replacement` | Leaf-replacement bindings tool (post-migration) |

See [`PROJECT_MAP.md`](PROJECT_MAP.md) for the complete cross-project reference.

---

## Files NOT in git

Excluded via `.gitignore` — must be created locally:

| File | Purpose |
|------|---------|
| `*.tfvars` | Terraform credentials |
| `*.tfstate*` | Terraform state |
| `.terraform/` | Provider cache |
| `vault.yml` / `vault_pass.txt` | Ansible Vault |
| `.env` | Per-stack credential block (e.g. `sac-johbarbe-AFRICOM-terraform-nac-ndo`) |
| `backend.hcl` / `local_override.tf` | Local backend config (e.g. `ndo-terraform-ipv6`) |
| `data/nac-aci-{kelley,deldin}-rendered/` | VMM YAML rendered from `TF_VAR_vcenter_*` |
| `*.json` (generated) | Bindings JSONs from `dump_bindings.py` / `generate_fi_bindings.py` |

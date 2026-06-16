# Master Reference — ACI / NXOS Infrastructure as Code

Quick-reference for servers, paths, CI jobs, runners, and scripts.
Companion to **`PROJECTS_LISTING.md`** (one row per repo with purpose + remotes).

> **Path note.** The repo formerly at `~/DC/ACI/terraform-esg/` was cloned/moved to
> `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/`. All paths below use the
> current name. If you see the old name anywhere else, treat it as stale.

---

## Servers

| Server | Hostname / IP | Purpose |
|--------|--------------|---------|
| Mac (local) | your laptop | Development, editing IaC |
| RHEL 8 (GitLab + repos) | the RHEL server | GitLab instance, bare repos |
| CI runner host | `apckw059aau0096` | Runs CI/CD jobs (shell executor) |
| NDO / ND (LAB) | `198.18.133.100` | Cisco Nexus Dashboard + NDO — lab |
| Kelley APIC (LAB) | see `africom-aci-apic/lab.tfvars` | NADE02 lab APIC |
| Del Din APIC (LAB) | see `africom-aci-apic/lab.tfvars` | NAIT03 lab APIC |

---

## GitLab Projects (on RHEL server)

| GitLab project | Mac path | What it does |
|----------------|----------|-------------|
| `root/terraform_redesign_esg` | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/` | ESG redesign + AFRICOM NIPR APIC & NDO IaC (this repo) |
| `root/ndo_terraform` | `sac-johbarbe-AFRICOM-terraform-nac-ndo/` | AFRICOM NIPR foundational NDO NAC stack |
| `root/n5k_replacement` | `NXOS/sac-johbarbe-AFRICOM-nxos-n5k/` | N5K snake bindings (Python + Ansible) |
| `root/aci-lf-rplc` | `NXOS/n5k/Snake/PRODUCTION/aci-lf-rplc/` | Leaf replacement bindings (Python + Ansible) |

---

## Mac — Workspace Files

| Workspace file | Path |
|----------------|------|
| `ACI_LAB` | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/ACI_LAB.code-workspace` |
| `ACI_PRODUCTION` | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/ACI_PRODUCTION.code-workspace` |
| `rcc-e` | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/rcc-e.code-workspace` |

---

## Mac — Key File Locations

### This repo (`sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/`)

| What | Path | README |
|------|------|--------|
| Repo root README | `README.md` | — |
| Lab deployment runbook | `README_LAB.md` | — |
| **AFRICOM NIPR implementation plan** | `docs/AFRICOM/AFRICOM_Implementation_Plan.md` | — |
| AFRICOM design review deck (PPTX) | `docs/AFRICOM/AFRICOM_ACI_Design_Review.pptx` | — |
| AFRICOM implementation plan (DOCX) | `docs/AFRICOM/AFRICOM_Implementation_Plan.docx` | — |
| **APIC direct — ESG redesign (lab + prod)** | `aci-apic/` | `aci-apic/README.md` |
| NDO schema — IPv4 redesign | `aci-ndo/` | `aci-ndo/README.md` |
| NDO schema — IPv6 RCC layer | `aci-ndo-ipv6/` | `aci-ndo-ipv6/README.md` |
| **APIC direct — AFRICOM NIPR (Kelley + Del Din)** | `africom-aci-apic/` | `africom-aci-apic/README.md` ← **start here for AFRICOM NIPR work** |
| NDO schema — AFRICOM NIPR V2 | `africom-aci-ndo/` | `africom-aci-ndo/README.md` |
| Phase 0 validation + automation script | `scripts/validate_fabric.py` | `africom-aci-apic/README.md` |
| FI binding parity check | `scripts/check_fi_bindings_parity.py` | — |
| Static port binding deploy | `scripts/deploy_bindings.py` | — |
| Root CI pipeline (umbrella) | `.gitlab-ci.yml` | `README.md` |
| AFRICOM NIPR CI pipeline | `africom-aci-apic/.gitlab-ci.yml` | `africom-aci-apic/README.md` |

### Sibling repo (`sac-johbarbe-AFRICOM-terraform-nac-ndo/`)

| What | Path |
|------|------|
| Foundational NDO NAC stack | repo root |
| NAC YAML data | `data/` |
| CI pipeline | `.gitlab-ci.yml` |
| Lab runbook | `README_LAB.md` |

### NXOS repos

| What | Path |
|------|------|
| N5K snake bindings | `NXOS/sac-johbarbe-AFRICOM-nxos-n5k/` |
| Leaf replacement (LAB) | `NXOS/n5k/Snake/LAB/aci-lf-rplc/` |
| Leaf replacement (PROD) | `NXOS/n5k/Snake/PRODUCTION/aci-lf-rplc/` |

---

## AFRICOM NIPR Implementation Plan — Automation Map

Where to find the automation for each implementation phase.

| Phase | What | Tool | Location |
|-------|------|------|----------|
| **0** — Pre-change validation | Health checks, APIC snapshot, NDO backup, schema export | Python | `scripts/validate_fabric.py` |
| **1.1** — Rogue EP Control (Del Din) | NAC YAML → Terraform | `africom-aci-apic/data/nac-aci-deldin/phase1-deldin-settings.nac.yaml` |
| **1.2** — Port Tracking (Kelley) | NAC YAML → Terraform | `africom-aci-apic/data/nac-aci-kelley/phase1-kelley-settings.nac.yaml` |
| **1.3** — BFD on fabric interfaces | NAC YAML → Terraform | `africom-aci-apic/data/nac-aci-shared/phase1-fabric-settings.nac.yaml` |
| **1.4** — FISAC Permissive → Strict | **Manual only** (no API) | See `docs/AFRICOM/AFRICOM_Implementation_Plan.md §1.4` |
| **1.5** — Disable Remote EP Learning | NAC YAML → Terraform | `africom-aci-apic/data/nac-aci-shared/phase1-fabric-settings.nac.yaml` |
| **2** — Access policy cleanup | NAC YAML → Terraform (pending VLAN audit) | `africom-aci-apic/data/nac-aci-{kelley,deldin}/` |
| **3** — Firewall & routing | **Manual only** (firewall/router config) | See `docs/AFRICOM/AFRICOM_Implementation_Plan.md §3` |
| **4** — VMM stabilization | **Manual only** (vCenter/AD) | See `docs/AFRICOM/AFRICOM_Implementation_Plan.md §4` |
| **5** — NDO schema cleanup | **Manual only** (NDO GUI — Move between templates has no REST API) | See `docs/AFRICOM/AFRICOM_Implementation_Plan.md §5` |
| **6** — ND HA & backup | Partial: backup creds/schedule via NAC YAML; node add is manual | `africom-aci-apic/data/nac-aci-shared/` |
| **7B** — Deploy V2 schema | NDO Terraform | `africom-aci-ndo/` |
| **7C** — Lift-and-shift ESGs | NAC YAML → Terraform | `africom-aci-apic/data/nac-aci-shared/tenant-afrdel-esgs.nac.yaml` |
| **7D** — BD-by-BD migration | Python script (extend deploy_bindings.py pattern) | `scripts/deploy_bindings.py` + per-BD manual gate in CI |
| **7G** — vzAny removal | NDO Terraform with hard manual gate | `africom-aci-ndo/` |

---

## .gitlab-ci.yml Files

| CI file | Stage | Trigger |
|---------|-------|---------|
| `.gitlab-ci.yml` (umbrella) | Orchestrates all sub-projects | push / MR |
| `aci-apic/.gitlab-ci.yml` | ESG redesign APIC (lab + prod) | changes to `aci-apic/**` or `PROJECT=apic-vmware` |
| `aci-ndo/.gitlab-ci.yml` | IPv4 redesign NDO schema | changes to `aci-ndo/**` or `PROJECT=aci-redesign-ndo` |
| `aci-ndo-ipv6/.gitlab-ci.yml` | IPv6 RCC NDO layer | changes to `aci-ndo-ipv6/**` or `PROJECT=aci-ndo-ipv6` |
| `africom-aci-apic/.gitlab-ci.yml` | **AFRICOM NIPR APIC** (Phase 0–2) | changes to `africom-aci-apic/**` or `PROJECT=africom-apic` |

Apply jobs are **always manual** (`when: manual`). Nothing auto-applies.

---

## CI/CD Variables (GitLab → Settings → CI/CD → Variables)

### AFRICOM NIPR (new — set for `africom-apic` jobs)

| Variable | Notes |
|----------|-------|
| `KELLEY_APIC_URL` | Kelley APIC `https://...` |
| `KELLEY_APIC_USERNAME` | usually `admin` |
| `KELLEY_APIC_PASSWORD` | **Masked** |
| `DELDIN_APIC_URL` | Del Din APIC `https://...` |
| `DELDIN_APIC_USERNAME` | usually `admin` |
| `DELDIN_APIC_PASSWORD` | **Masked** |
| `NDO_URL` | Nexus Dashboard `https://...` |
| `NDO_USERNAME` | NDO username |
| `NDO_PASSWORD` | **Masked** |
| `PHASE0_FULL` | Set to `true` in Run Pipeline dialog before a change window to enable APIC snapshots + NDO backup + schema export |
| `KELLEY_APIC_URL_PROD` … `DELDIN_APIC_PASSWORD_PROD` | Prod variants — same pattern, `_PROD` suffix, **Masked + Protected** |

### ESG redesign + IPv6 (existing)

| Variable | Notes |
|----------|-------|
| `KELLEY_MCP_KEY` / `DELDIN_MCP_KEY` | MCP instance policy key ≥8 chars, **Masked** |
| `VCENTER_HOSTNAME_IP` / `VCENTER_DATACENTER` / `VCENTER_DVS_VERSION` | VMM domain prereqs |
| `VCENTER_USERNAME` / `VCENTER_PASSWORD` | **Masked + Protected** |
| `GITLAB_TOKEN` | User access token for MR comments, **Masked** |
| `NDO_USERNAME` / `NDO_PASSWORD` / `NDO_URL` | Shared with AFRICOM validate jobs |

---

## GitLab Runner

| Detail | Value |
|--------|-------|
| Runner name | `aci-automation-runner` |
| Executor | Shell (NOT Docker) |
| Runner host | `apckw059aau0096` |
| Runner binary | `~/gitlab-runner/gitlab-runner` |
| Runs as | Background process (no systemd) |

### Share the runner with new projects

1. IPv6 project → Settings → CI/CD → Runners → pencil icon → uncheck **Lock to current projects**
2. Each new project → Settings → CI/CD → Runners → enable `aci-automation-runner`

### Start / restart

```bash
ssh apckw059aau0096
pkill gitlab-runner
nohup ~/gitlab-runner/gitlab-runner run &
ps aux | grep gitlab-runner
```

### Shell runner rules (important — Docker rules do NOT apply here)

1. No `image:` line
2. No `---` at the top of the file
3. No `description:` / `value:` sub-keys under `variables:`
4. Use `only:` not `rules:` (or omit — defaults to any branch)
5. Inline everything (no `extends:`)

---

## Scripts Quick Reference

### AFRICOM NIPR implementation

| Command | What it does |
|---------|-------------|
| `python3 scripts/validate_fabric.py` | Phase 0 health check only (read-only) |
| `python3 scripts/validate_fabric.py --phase0 --artifacts-dir scripts/baseline/pre-phase1` | Full Phase 0: health check + APIC snapshot + NDO backup + schema export |
| `python3 scripts/validate_fabric.py --compare scripts/baseline/pre-phase1/baseline.json` | Post-change drift report |
| `python3 scripts/validate_fabric.py --skip-ndo` | Skip NDO checks (when ND is unreachable) |

### ESG redesign binding scripts

| Command | What it does |
|---------|-------------|
| `python3 scripts/deploy_bindings.py` | Deploy V2 EPG static port bindings to NDO |
| `python3 scripts/dump_bindings.py` | Export existing NDO binding paths (used to seed V2) |
| `python3 scripts/check_fi_bindings_parity.py` | Verify FI binding manifest matches NDO schema |
| `python3 scripts/generate_fi_bindings.py` | Regenerate FI binding manifest from schema |

### Terraform workflow (AFRICOM NIPR APIC)

```bash
cd africom-aci-apic
bash scripts/render-vmm-yaml.sh kelley    # generates gitignored VMM YAML
bash scripts/render-vmm-yaml.sh deldin
make plan                                  # lab.tfvars
make apply

# Prod:
make plan   TFVARS_FILE=prod.tfvars
make apply
```

---

## What runs where

| Goal | Repo / path | Driver |
|------|-------------|--------|
| AFRICOM NIPR health check + Phase 0 automation | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/scripts/validate_fabric.py` | `python3` direct or CI `phase0-validate-africom` job |
| AFRICOM NIPR Phase 1–2 APIC settings | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/africom-aci-apic/` | `make plan && make apply` or CI `phase1-*-africom` jobs |
| AFRICOM NIPR V2 NDO schema | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/africom-aci-ndo/` | `make plan && make apply` (then Deploy in NDO UI) |
| AFRICOM NIPR foundational NDO stack | `sac-johbarbe-AFRICOM-terraform-nac-ndo/` | `terraform plan && terraform apply` |
| ESG redesign APIC (lab + prod) | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-apic/` | `make plan && make apply` or CI |
| ESG redesign NDO schema | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo/` | `make plan && make apply` (then Deploy) |
| IPv6 RCC NDO layer | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo-ipv6/` | `make plan && make apply` |
| V2 EPG static port bindings | `sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/scripts/deploy_bindings.py` | `python3` after NDO deploy |
| N5K-derived bindings (legacy) | `NXOS/sac-johbarbe-AFRICOM-nxos-n5k/` | ansible + `deploy_bindings_python_v2.py` or CI |
| Leaf replacement bindings | `NXOS/n5k/Snake/{LAB,PRODUCTION}/aci-lf-rplc/` | ansible + `deploy_bindings_python.py` |

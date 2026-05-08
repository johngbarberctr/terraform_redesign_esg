# aci-redesign / ndo — Lab

This directory **is** the lab variant. There is no separate `aci-redesign/ndo-prod/` — the production-side equivalent lives in `~/DC/ACI/ndo-terraform-nac-prod/`, which uses the netascode wrapper against a different schema (`AEDCE`) and customer NDO. The redesign here always targets the **lab** NDO at `198.18.133.100` and the **AEDCE-IPv4** schema.

The full architectural README is in [`README.md`](README.md). This file is the short lab-focused runbook. Follow this for daily lab work; reach for `README.md` when you need the cutover sequence or template structure.

> **Two ways to drive this stack:**
>
> 1. **Local Terraform from your laptop** (this walkthrough). State is a local file (`terraform.tfstate`) when you set up the [local backend override](#one-time-setup) below.
> 2. **GitLab CI** — push to a branch / open MR for plan, merge to `main` for an apply (manual button). State lives in the GitLab HTTP backend authenticated with `${CI_JOB_TOKEN}` (no PAT needed). See [`README.md` → "CI/CD pipeline"](README.md#cicd-pipeline).
>
> Pick one mode per change. Mixing local and CI state writes will produce confusing state lineage.

---

## Lab connection

| Setting | Value |
|---|---|
| NDO URL | `https://198.18.133.100` |
| NDO user | `admin` |
| NDO platform | `nd` (Nexus Dashboard hosted) |
| NDO domain | `local` |
| Schema | `AEDCE-IPv4` (1 template: `Tenant_EUR_IPv4` — contains 2 VRFs, 39 BDs, 2 ANPs, 39 EPGs, 2 contracts) |
| Tenant | `EUR` (already present in NDO; this stack does not own it) |
| Sites | `AEDCG`, `AEDCK` (already onboarded into NDO) |

The non-sensitive bits (`ndo_url`, `ndo_username`, `ndo_platform`, `ndo_domain`, `ndo_insecure`) live in `terraform.tfvars` (gitignored — copy from `terraform.tfvars.example` if missing). The password comes from `TF_VAR_ndo_password`.

## One-time setup

```bash
cd ~/DC/ACI/terraform-esg/aci-redesign/ndo

# 1. Local backend override — gitignored, never reaches CI. Without this,
#    `terraform init` will fail with "backend \"http\": missing \"address\"
#    config" because main.tf declares backend "http" {} for CI.
ls local_override.tf >/dev/null 2>&1 || cat > local_override.tf <<'EOF'
terraform {
  backend "local" {}
}
EOF

# 2. Non-sensitive values
test -f terraform.tfvars || cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

# 3. Sensitive value — env var, never tfvars
source scripts/set-ndo-password.sh   # prompts; exports TF_VAR_ndo_password

# 4. Sanity check (POST /login to NDO)
make auth-check

# 5. terraform init (downloads netascode/nac-ndo/mso 1.2 + CiscoDevNet/mso ~> 1.6)
make init
```

## Daily lab workflow

```bash
cd ~/DC/ACI/terraform-esg/aci-redesign/ndo

# `set-ndo-password.sh` exports the env var only into the current shell -- run it once
# per shell session, then:
make plan
make apply
```

`make` wraps `terraform plan -out=plan.tfplan` and `terraform apply plan.tfplan`. The Makefile fails fast if `TF_VAR_ndo_password` is unset.

After `make apply` succeeds, the schema, template, VRFs, BDs, EPGs, contracts, and the cross-schema filter reference exist in NDO **but are not deployed to AEDCG/AEDCK** — `deploy_templates = false` in `main.tf`. Push manually from the NDO UI: **Application Management → Schemas → AEDCE-IPv4 → `Tenant_EUR_IPv4` → Deploy to sites**, target both `AEDCG` and `AEDCK`. There is **only one template** in this schema.

> **Heads-up.** `AEDCE-IPv4` cross-references the `Any` filter from
> `AEDCE / VRF_Template`. That filter is created by the sibling repo
> `~/DC/ACI/ndo-terraform-nac-prod/` (Phase 1 of the canonical runbook).
> If you skipped it, `make plan` will fail to resolve the cross-schema
> reference. See [`../../README_LAB.md`](../../README_LAB.md) Phase 1.

## Where this fits in the wider lab build

This is **Phase 4** of the canonical runbook in [`../../README_LAB.md`](../../README_LAB.md).
Briefly:

1. `~/DC/ACI/ndo-terraform-nac-prod/` — foundational NDO build (tenant `EUR`, schema `AEDCE`, 5 templates incl. the `Any` filter we cross-reference)
2. NDO UI — deploy the 5 `AEDCE` templates in strict order
3. `../apic-vmware/` — APIC access/fabric/VMM (creates the per-fabric VMM domains `APCG-VDS1` / `APCK-VDS1` that this stack's EPGs bind to)
4. **this directory** — IPv4 redesign tenant tree (`AEDCE-IPv4` / `Tenant_EUR_IPv4`)
5. NDO UI — manual deploy of `Tenant_EUR_IPv4` to AEDCG and AEDCK
6. `~/DC/ACI/terraform-esg/ndo-terraform-ipv6/` (optional) — IPv6 RCC layer on top
7. `../scripts/deploy_bindings.py` — static port bindings push

The full sequence with timing, verification, and rollback is in
[`../../README_LAB.md`](../../README_LAB.md). Production cutover is in
[`../README.md`](../README.md) ("Production cutover runbook").

## Troubleshooting

### `Post "/login": unsupported protocol scheme ""`

`var.ndo_url` is empty. Either `terraform.tfvars` doesn't exist (copy from `.example`), or `ndo_url` is set to a placeholder string. The same trap exists in `~/DC/ACI/terraform-esg/ndo-terraform-ipv6/` — see that directory's `README_LAB.md` troubleshooting.

### `make auth-check` returns 401

Either `TF_VAR_ndo_password` isn't exported, or the lab NDO password rotated since you sourced `set-ndo-password.sh`. Re-source it.

### `make plan` shows mass destruction

Most likely the schema name in `data/nac-ndo/` no longer matches what NDO has. Compare `name:` in `../data/nac-ndo/schema-aedce-ipv4.nac.yaml` against what NDO actually shows.

### `Failed to obtain provider schema` for CiscoDevNet/mso

Stale `.terraform/`. `make clean && rm -rf .terraform .terraform.lock.hcl && make init`.

### `Error: Error loading state: HTTP remote state endpoint requires auth`

`local_override.tf` is missing — Terraform fell back to the empty `backend "http" {}` in `main.tf`. Recreate it (Setup step 1) and `terraform init -reconfigure`.

### `Duplicate Resource: "name"{"Name":["Schema 'AEDCE-IPv4' already exists"]}` on first CI apply

Empty GitLab state slot but NDO already has the schema (e.g. someone applied locally before CI was wired up). Migrate your laptop's `terraform.tfstate` into the GitLab slot — see [`README.md` → Troubleshooting](README.md#troubleshooting) for the `terraform init -migrate-state -force-copy` recipe shared across all four projects.

## Files in this directory (lab perspective)

| File | Touch in lab? |
|---|---|
| `main.tf` | rarely — module call only (declares `backend "http" {}` for CI) |
| `local_override.tf` | once (gitignored — see [Setup step 1](#one-time-setup)) |
| `providers.tf` | rarely |
| `variables.tf` | rarely |
| `terraform.tfvars` | when lab IPs/creds change |
| `terraform.tfvars.example` | rarely (template only) |
| `Makefile` | never |
| `.gitlab-ci.yml` | when CI behavior changes (you usually don't) |
| `scripts/auth-check.sh`, `scripts/set-ndo-password.sh` | as helpers |
| `terraform.tfstate*` | never (state — `terraform` manages; only present with `local_override.tf`) |
| `plan.tfplan`, `destroy.tfplan` | disposable; `make clean` removes them |
| `README.md` | architecture, cutover sequence, CI/CD pipeline reference |
| `README_LAB.md` (this file) | lab daily-driver |

## What this README deliberately does not cover

- Cutover sequence from APIC-direct to NDO (see `README.md`).
- Schema content, template structure, ESG modeling decisions (see `README.md` and `../data/nac-ndo/schema-aedce-ipv4.nac.yaml` comments).
- Production NDO-NAC stack (see `~/DC/ACI/ndo-terraform-nac-prod/README.md`).
- IPv6 RCC layer on top of this schema (see `~/DC/ACI/terraform-esg/ndo-terraform-ipv6/README_LAB.md`).
- Canonical end-to-end deployment runbook (see `~/DC/ACI/terraform-esg/README_LAB.md`).

# aci-redesign / apic-vmware-prod

Production sister of `../apic-vmware/` (the lab APIC-direct root). Same
Terraform code shape; targets the production AEDCG and AEDCK APICs.

## Why a separate root

- **Strict state separation.** Lab state (`aci-redesign`) and prod state
  (`aci-redesign-prod`) are stored under different GitLab Terraform
  state paths. There is no possibility of one root `apply` touching both
  environments.
- **Separate CI variables.** `*_PROD` masked GitLab CI variables feed this
  root; the lab job ignores them. See `.gitlab-ci.yml` `validate-aci-prod`,
  `plan-aci-prod`, `deploy-aci-prod`.
- **Different YAML surface.** This root reads:
    - `../data/nac-aci-shared/`            (cross-environment policy)
    - `../data/nac-aci-aedcg-prod/`        (prod AEDCG: PC_FI_A/B, fi pool, leaf 152/153 split)
    - `../data/nac-aci-aedck-prod/`        (prod AEDCK: leaf 119/191 split)
    - `../data/nac-aci-aedcg-prod-rendered/` (gitignored; produced by `make render`)
    - `../data/nac-aci-aedck-prod-rendered/` (gitignored)
- **Manual deploy.** `deploy-aci-prod` is `when: manual` to enforce a
  change-window. `terraform apply` from a workstation also works for
  Out-Of-Band activity if the runner is unavailable, provided the
  operator has the `*_PROD` env vars set.

## Local workflow (operator)

```bash
cd aci-redesign/apic-vmware-prod
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars        # set aedcg_apic_url / aedck_apic_url

# Sensitive values via env vars (do NOT put in terraform.tfvars):
export TF_VAR_aedcg_apic_password='...'
export TF_VAR_aedck_apic_password='...'
eval "$(./scripts/generate-mcp-key.sh aedcg)"
eval "$(./scripts/generate-mcp-key.sh aedck)"

# vCenter env vars are shared with the lab if same vCenter; otherwise prod
# specific:
export TF_VAR_vcenter_hostname_ip=...
export TF_VAR_vcenter_datacenter=...
export TF_VAR_vcenter_username=...
export TF_VAR_vcenter_password=...
export TF_VAR_vcenter_dvs_version='unmanaged'

make auth-check                 # confirm credentials work BEFORE terraform
make plan                       # renders both fabrics, then plans
make apply                      # only after plan review
```

For partial fabric work:

```bash
make plan
make apply-aedcg                # AEDCG only
make apply-aedck                # AEDCK only
```

## Pre-cutover helper

If the production APICs still have a legacy VMM domain (e.g.
`vmm-vcenter-rcc`) that needs to be removed before APIC adopts
`APCG-VDS1` / `APCK-VDS1`:

```bash
OLD_DOMAIN=vmm-vcenter-rcc make cleanup-old-vmm
# (or any other legacy name if production differs from lab)
```

This script is idempotent and skips the API call if the domain is already
absent. Always run from a fresh shell with `TF_VAR_*_apic_password` exported.

## Files

| File | Purpose |
| --- | --- |
| `main.tf` | Two `module "aci_<fabric>"` calls + inline `aci_rest_managed.mcp_inst_pol_*` per fabric. Mirrors lab. |
| `providers.tf` | `aci` (default → AEDCG), `aci.aedck` (alias → AEDCK). |
| `variables.tf` | Same variable names as lab; descriptions updated to "production". |
| `Makefile` | `init`/`fmt`/`validate`/`plan`/`apply{-fabric}`/`destroy{-fabric}`/`render`/`auth-check`/`cleanup-old-vmm`. |
| `terraform.tfvars.example` | Non-sensitive shape; copy to `terraform.tfvars`. |
| `scripts/render-vmm-yaml.sh` | Writes to `*-prod-rendered/` (note suffix). |
| `scripts/auth-check.sh` | POST aaaLogin to either fabric. |
| `scripts/cleanup-old-vmm-domain.sh` | Pre-cutover legacy VMM domain delete (parameterised via `OLD_DOMAIN`). |
| `scripts/generate-mcp-key.sh` | Same as lab. Run twice (one per fabric). |
| `templates/vmm-domain.nac.yaml.tftpl` | Same as lab. |

# aci-ndo — V2 consolidated tenant redesign (NDO-managed)

Manages the AFRICOM-V2 schema in Nexus Dashboard Orchestrator: 2 VRFs, 39 BDs,
2 ANPs, 39 EPGs, 2 vzAny contracts. All tenant-scoped objects carry a `-V2`
suffix to coexist with the legacy `AFRICOM` schema in tenant `AFR-DEL.Services`.

See `docs/DESIGN.md` for naming-convention rationale.

## Prerequisites

Phase 1 (sibling repo `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/`) must have been
applied and its templates manually deployed before running `plan` here.
This root references the `Any` filter under `AFRICOM/VRF_Template` via a
cross-schema link; plan fails if that object doesn't exist in NDO.

## Data layout

```
data/nac-ndo/        NDO YAML — sites, tenants, schemas
                     Schema AFRICOM-V2 / template Tenant_AFR-DEL.Services_V2
```

## Local workflow

```bash
cd ~/DC/ACI/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/aci-ndo

# Backend: use local state on laptop (gitignored local_override.tf already present)
export TF_VAR_ndo_username='...'
export TF_VAR_ndo_password='...'
export TF_VAR_ndo_url='https://...'

terraform init
terraform plan  -parallelism=3
terraform apply -parallelism=3 -auto-approve
```

After apply, the schema content is in NDO but **not yet deployed to APIC**.
Manual NDO UI step:

> Application Management → Schemas → AFRICOM-V2 → Tenant_AFR-DEL.Services_V2 →
> Deploy to sites → [Kelley, Del-Din]

## GitLab CI

Three jobs in `aci-ndo/.gitlab-ci.yml`:

| Job | Stage | Trigger |
|---|---|---|
| `validate-aci-redesign-ndo` | validate | MR or push to `aci-ndo/**` |
| `plan-aci-redesign-ndo` | plan | same |
| `apply-aci-redesign-ndo` | deploy | manual, `main` only |

State key: `aci-redesign-ndo` (do NOT rename — live state exists).

## Module flags

| Flag | Value | Why |
|---|---|---|
| `manage_sites` | false | Kelley/Del-Din already onboarded in NDO |
| `manage_tenants` | false | tenant AFR-DEL.Services pre-exists, owned out of band |
| `manage_schemas` | true | this root owns AFRICOM-V2 |
| `deploy_templates` | false | deploy is a manual NDO UI click for now |

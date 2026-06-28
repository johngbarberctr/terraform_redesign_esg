# aci-apic — APIC legacy IPv4 + ESG root (Kelley + Del-Din)

Manages APIC-direct objects for both AFRICOM ACI fabrics (Kelley = site1,
Del-Din = site2) in a single Terraform root. Uses two provider aliases and two
`netascode/nac-aci` module instances. Lab and production targets share this
directory; environment distinction is handled via tfvars files and GitLab CI
variables.

**Scope: legacy IPv4 infrastructure + the ESG/tenant layer only.** The
`access-policies.nac.yaml` files here manage just the pre-existing legacy
IPv4 / N5K-migration objects: `VLAN_All_Combined` (static pool),
`PhysDom_ACI_Nexus`, `L3_Dom_ND`, `AAEP_ACI_Nexus`, and the shared
CDP/LLDP/port-channel/link-level interface policies the N5K-migration VPC/PC
groups (`VPC_D1A-B`, …) reference. The base (`nac-aci-site{1,2}/`) and prod
(`nac-aci-site{1,2}-prod/`) files are identical by design; only environment
values (IPs/credentials) differ, via tfvars / CI variables.

> **FI uplinks and the VMware VMM domain are NOT managed here.** They are owned
> exclusively by the canonical **`africom-aci-apic/`** stack (`VPC_FI-A` /
> `VPC_FI-B` vPCs on eth1/6-7 + `Kelley-VDS1` / `Del-Din-VDS1` on `fi-aaep`).
> This stack and `africom-aci-apic/` target the same APICs; keeping FI/VMM in a
> single stack avoids two Terraform states fighting over the same APIC MOs.
> Because no VMM domain is referenced or created here, vCenter env vars are not
> needed for this stack.

## Data layout

```
data/
  nac-aci-shared/          tenant EUR, ESGs, vzAny contracts (same on both fabrics)
  nac-aci-site1/           Kelley legacy IPv4 objects (VLAN_All_Combined, PhysDom_ACI_Nexus, L3_Dom_ND, AAEP_ACI_Nexus)
  nac-aci-site1-prod/      Kelley prod (identical design to nac-aci-site1; IPs/creds via tfvars)
  nac-aci-site2/           Del-Din legacy IPv4 objects (same shape as site1)
  nac-aci-site2-prod/      Del-Din prod (identical design to nac-aci-site2; IPs/creds via tfvars)
```

> No `*-rendered/` VMM directories are used by this stack — the VMM domain is
> owned by `africom-aci-apic/`. `make render` is a no-op here.

## Environment selection

| File | When |
|---|---|
| `lab.tfvars` | Lab APIC IPs, `manage_tenants = true` |
| `prod.tfvars` | Prod APIC IPs, `manage_tenants = false` |

`manage_tenants = true` lets this root own the `mso_tenant` resource (needed
in lab where tenant EUR may not yet exist). Prod sets it false because tenant
EUR is pre-created by the NDO NAC prod pipeline.

**No Python venv required.** All `make` targets use bash scripts and `terraform`
only. Scripts call `python3` stdlib (`json`, `os`, `sys`) for JSON escaping —
no pip packages needed.

Local workflow:

```bash
# Lab
source scripts/set-apic-password.sh              # sets TF_VAR_kelley/deldin_apic_password
eval "$(./scripts/generate-mcp-key.sh kelley)"  # TF_VAR_kelley_mcp_key
eval "$(./scripts/generate-mcp-key.sh deldin)"  # TF_VAR_deldin_mcp_key
# NOTE: TF_VAR_vcenter_* vars are NOT needed — no VMM domain here (owned by
#       africom-aci-apic/). This stack manages only legacy IPv4 + ESG objects.
make init                   # first time or after module/provider bumps
make auth-check             # verify APIC connectivity before plan
make plan                   # uses lab.tfvars by default
make apply

# Prod (override var-file and pass prod secrets via env)
export TF_VAR_kelley_apic_password='...'
export TF_VAR_deldin_apic_password='...'
export TF_VAR_kelley_mcp_key='...'
export TF_VAR_deldin_mcp_key='...'
make plan    TFVARS_FILE=prod.tfvars
make apply
```

## GitLab CI

Four jobs in `aci-apic/.gitlab-ci.yml` (two pairs: lab + prod):

| Job | Stage | Trigger |
|---|---|---|
| `validate-apic-vmware` | validate | auto — any push/MR changing `aci-apic/**` |
| `plan-apic-vmware` | plan | auto — same |
| `apply-apic-vmware` | deploy | **manual** — `main` branch only |
| `validate-apic-vmware-prod` | validate | **manual only** — set `PROJECT=apic-vmware-prod` |
| `plan-apic-vmware-prod` | plan | **manual only** — set `PROJECT=apic-vmware-prod` |
| `apply-apic-vmware-prod` | deploy | **manual only** — set `PROJECT=apic-vmware-prod` |

Prod jobs never run automatically. To trigger them:

1. Go to `http://localhost:8080/root/sac-johbarbe-AFRICOM-terraform-esg-nac-ndo/-/pipelines/new`
2. Branch: `main`
3. Add variable: **`PROJECT`** = **`apic-vmware-prod`**
4. Click **Run pipeline**

For lab, same steps with **`PROJECT`** = **`apic-vmware`** (or just push to `aci-apic/**`).

State keys (do NOT rename — live state exists):

- Lab: `aci-redesign`
- Prod: `aci-redesign-prod`

## Key variables

| Variable | Where set | Notes |
|---|---|---|
| `kelley_apic_url / deldin_apic_url` | tfvars | APIC HTTPS endpoints |
| `kelley_apic_username / deldin_apic_username` | tfvars | usually `admin` |
| `kelley_apic_password / deldin_apic_password` | env / CI masked | never committed |
| `kelley_mcp_key / deldin_mcp_key` | env / CI masked | >=8 chars, mixed |
| `vcenter_hostname_ip` / `vcenter_datacenter` / `vcenter_dvs_version` | ~~tfvars~~ | **Not required** — no VMM/FI here; owned by `africom-aci-apic/` |
| `vcenter_username` / `vcenter_password` | ~~env / CI masked~~ | **Not required** — no VMM/FI here; owned by `africom-aci-apic/` |
| `manage_tenants` | tfvars | `true` = lab, `false` = prod |

## Troubleshooting

See `docs/DESIGN.md` for the BD/EPG/ESG design rationale and `README_LAB.md`
Phase 3 for the full step-by-step lab runbook.

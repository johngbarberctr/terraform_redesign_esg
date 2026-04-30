# aci-redesign / ndo

NDO-managed tenant root for the IPv4 redesign. NDO (one control plane) pushes
tenants, VRFs, BDs, contracts, EPGs, and ESGs down to both AEDCG and AEDCK
APICs.

## What lives here vs. apic-vmware/

| Layer                                                  | Where it lives                | Why                                                                                |
| ------------------------------------------------------ | ----------------------------- | ---------------------------------------------------------------------------------- |
| Access policies, fabric policies, switch/leaf profiles | `../apic-vmware/`             | Per-fabric infrastructure -- AAEP, VPCs, leaf profiles differ.                     |
| MCP instance policy                                    | `../apic-vmware/`             | Fabric-local; per-site shared key.                                                 |
| VMware VMM domain object (`vmmDomP`)                   | `../apic-vmware/`             | Lives on each APIC; NDO references it but does not create it.                      |
| Tenant `EUR`                                           | `../data/nac-ndo/tenant.nac.yaml` | Single tenant pushed to both AEDCG and AEDCK.                                  |
| Schema `AEDCE-IPv4` (3 templates)                      | `../data/nac-ndo/schema-aedce-ipv4.nac.yaml` | All VRFs, filters, contracts, BDs, ANPs, EPGs in one consolidated file.   |
| ESGs                                                   | NOT in NDO yet                | The nac-ndo wrapper module doesn't ship ESG support; vzAny+permit-all on each VRF replaces them functionally. |

## Quick start

```bash
cd aci-redesign/ndo

# 1. Fill in non-sensitive connection values.
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars        # ndo_url, ndo_username, ndo_platform, ndo_domain

# 2. Set the sensitive value via env (never commit).
source scripts/set-ndo-password.sh

# 3. Sanity check.
make auth-check

# 4. Plan + apply.
make init
make validate
make plan
make apply
```

## Deployment order (cutover from APIC-direct -> NDO)

The IPv4 tenant tree was previously created directly on the APIC by
`../apic-vmware/`. Lab is a clean-slate environment, so the move is
destructive: there is no Terraform state hand-off because the resources live
in different roots and were created by different providers.

1. In `../apic-vmware/`, `manage_tenants = false` is already set on both
   fabric modules. Run `make apply` there. The APIC-direct providers delete
   tenant `EUR` and its children (VRFs, BDs, EPGs, ESGs, contracts, filters,
   ANPs) on both AEDCG and AEDCK. Access/fabric/MCP/VMM-domain objects are
   untouched.
2. Sanity check that NDO can still see both sites and that AEDCG and AEDCK
   show up healthy.
3. From this root: `make plan` then `make apply`. NDO creates tenant `EUR`,
   pushes the Tenant_Policy template (deploy order 1), then Stretched_BDs
   (order 2), then App_Profiles (order 3). NDO undeploy ordering is
   automatic on destroy.
4. Verify in NDO UI and on each APIC that EPG-to-VMM bindings resolved and
   endpoints are learning.

## Environment variables

| Var                     | Required | Purpose                                          |
| ----------------------- | -------- | ------------------------------------------------ |
| `TF_VAR_ndo_password`   | yes      | NDO admin password. Use `set-ndo-password.sh`.   |

`ndo_url`, `ndo_username`, `ndo_platform`, `ndo_domain`, `ndo_insecure` come
from `terraform.tfvars`.

## Files

```
ndo/
├── main.tf                       # netascode/nac-ndo/mso module call
├── providers.tf                  # mso provider
├── variables.tf                  # ndo_* variables
├── terraform.tfvars.example      # commit this; copy to terraform.tfvars
├── Makefile                      # init/fmt/validate/plan/apply/destroy/auth-check
├── scripts/
│   ├── auth-check.sh             # POST /login to NDO with current creds
│   └── set-ndo-password.sh       # source to export TF_VAR_ndo_password
└── README.md
```

YAML lives one level up:

```
../data/nac-ndo/
├── tenant.nac.yaml               # tenant EUR + site associations (AEDCG, AEDCK)
└── schema-aedce-ipv4.nac.yaml    # consolidated schema with 3 templates:
                                  #   * Tenant_Policy   (VRFs, filter Any, Any_VRF-* contracts)
                                  #   * Stretched_BDs   (39 BDs, l2_stretch=true by default)
                                  #   * App_Profiles    (AppProf-NetCentric + AppProf-DMZ EPGs)
```

The plan originally called for one file per template, but yaml_merge keying
on deeply-nested lists is fragile. Production (`ndo-terraform-nac/data/ndo/
schema_AEDCE.nac.yaml`, 15k lines) keeps everything in a single schema
file; we follow the same pattern and use comment-delimited section headers
instead of file splits. Section navigation: search the file for
`Template 1`, `Template 2`, or `Template 3`.

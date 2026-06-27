# nac-aci-shared

YAML loaded by **both** APIC-direct fabric modules in
`../../africom-aci-apic/main.tf` (Kelley and Del Din).

## What lives here

| File | Purpose |
| --- | --- |
| `modules.nac.yaml` | Disable the wrapper's built-in MCP sub-module; MCP is managed inline in `main.tf`. |
| `tenant-afrdel-esgs.nac.yaml` | AFR-DEL.Services tenant stub + ESG layer (stubs — populate after NDO schema export and vzAny removal). |

## What does NOT live here

Tenant BDs, EPGs, VRFs, contracts, and filters are managed by NDO via the
sister Terraform root in `../../africom-aci-ndo/`. The NDO schema is
`schema-africom-nipr.nac.yaml` under that root's `data/nac-ndo/` directory.

When you need to change tenant BD/EPG content, edit the NDO YAML and redeploy
the affected templates from NDO UI. Both APIC modules here run with
`manage_tenants = var.manage_tenants` — set `false` in prod.tfvars since
AFR-DEL.Services is pre-created by the NDO pipeline.

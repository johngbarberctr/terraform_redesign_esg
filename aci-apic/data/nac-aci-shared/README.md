# nac-aci-shared

YAML loaded by **both** APIC-direct fabric modules in
`../../apic-vmware/main.tf` (AEDCG and AEDCK).

## What lives here

| File | Purpose |
| --- | --- |
| `modules.nac.yaml` | Disable the wrapper's built-in MCP sub-module; MCP is managed inline in `apic-vmware/main.tf`. |

## What does NOT live here anymore

The previous `tenant-epg-nac.nac.yaml` (the EUR tenant + BDs + EPGs +
contracts) was moved to `../_archive/tenant-epg-nac.nac.yaml.archived` when
tenant management migrated to NDO. The new source of truth is
`../nac-ndo/schema-aedce-v2.nac.yaml`, consumed by the sister Terraform
root in `../../ndo/`. Both APIC modules now run with `manage_tenants =
false`.

When you need to change tenant content, edit the NDO YAML; APIC will pick
up the change automatically once the schema is redeployed by NDO.

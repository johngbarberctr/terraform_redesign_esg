# Archived YAML

Files in this directory are NOT loaded by any Terraform root. They use a
trailing `.archived` extension precisely so the `*.{yml,yaml}` globs in the
netascode wrapper modules skip them.

## Files

### `tenant-epg-nac.nac.yaml.archived`

Original APIC-direct tenant model for the IPv4 redesign (EUR tenant: 2 VRFs,
39 BDs, 39 EPGs across two app profiles, plus 2 ESGs).

**Superseded by:** `../nac-ndo/schema-aedce-ipv4.nac.yaml`, which models the
same tenant tree as a Multi-Site schema and pushes it through NDO. APIC no
longer manages the tenant directly -- both `aci_aedcg` and `aci_aedck`
modules in `../../apic-vmware/main.tf` now have `manage_tenants = false`.

Kept around for diff/audit purposes only. If you need to evolve the tenant
model, edit the NDO YAML, not this file.

### `blueprint-rcc-vmm-nac.nac.yaml.archived`

Single-EPG NAC blueprint that demonstrated attaching `EPG-NAC` to the legacy
shared `vmm-vcenter-rcc` VMM domain (back when both fabrics were expected to
share one VDS). Superseded by the per-fabric VMM scheme (`APCG-VDS1` on AEDCG,
`APCK-VDS1` on AEDCK) defined in:

- `../nac-aci-aedcg-rendered/vmm-domain.nac.yaml` (rendered by
  `../../apic-vmware/scripts/render-vmm-yaml.sh aedcg`)
- `../nac-aci-aedck-rendered/vmm-domain.nac.yaml` (rendered by
  `../../apic-vmware/scripts/render-vmm-yaml.sh aedck`)
- the EPG-to-VMM bindings in
  `../nac-ndo/schema-aedce-ipv4.nac.yaml`.

Kept here as a worked example of the simple "one EPG, one VMM domain" shape
in case anyone needs it as a starting point for an unrelated APIC tenant.

# LAB - ACI Redesign (aci-redesign)

Reference configurations, blueprints, and Terraform projects for the ACI network redesign. Contains NAC YAML blueprints (both NDO and direct-APIC formats), migration phase plans, and VMware VMM domain integration via the `netascode/nac-aci` Terraform module.

## VMware VMM Integration

VMM integration uses dynamic VLAN assignment from pool **3501-3967** (avoids IPv6 range 3001-3500 and ACI reserved 3968-4095). When an EPG is bound to the VMM domain, ACI auto-assigns a VLAN from this pool and creates a port group on the VDS in vCenter.

### VLAN Strategy

| Range | Use | Allocation |
|-------|-----|------------|
| 3001-3500 | IPv6 RCC EPGs (existing static) | Static |
| **3501-3967** | **VMM domain (IPv4 EPGs)** | **Dynamic** |
| 3968-4095 | ACI reserved (do not use) | N/A |

### Production Config (ndo_terraform_nac)

VMM domain `VMM1` is configured in the production APIC site config and referenced by all ~266 EPGs in the NDO schema:

| File | What changed |
|------|-------------|
| `data/sites/primary/access_policies.nac.yaml` | VLAN pool `VMM1` set to 3501-3967, AAEP infra_vlan enabled, VPC-VMM-HOSTS policy group added |
| `data/sites/primary/fabric_policies.nac.yaml` | VMM domain `VMM1` updated with read-write, tag collection, mac-pinning, uplinks, dvs_version |
| `data/ndo/schema_AEDCE.nac.yaml` | All 405 EPG site entries have `vmware_vmm_domains` binding to `VMM1` (dynamic VLAN, immediate deployment) |

Before applying, update CHANGE_ME placeholders in `fabric_policies.nac.yaml` with real vCenter IP, datacenter, and credentials.

## Directory Structure

```
aci-redesign/
├── apic-vmware/              Terraform project -- deploy VMM domain + VDS + EPG to APIC via nac-aci
├── data/
│   ├── nac-aci-vmm/          NAC-ACI YAML configs consumed by apic-vmware/main.tf
│   │   ├── vmm-domain.nac.yaml       VMM domain + vCenter + VDS (fabric_policies)
│   │   ├── access-policies.nac.yaml   VLAN pool (3501-3967), AAEP, interface policies, leaf profiles
│   │   └── tenant-epg-nac.nac.yaml    VRF, Bridge Domain, EPG on VMM domain (dynamic VLAN)
│   ├── blueprints/           NAC YAML blueprints (design references, nac-aci format)
│   └── archive/              Archived NDO NAC configs (migration phases, alternate approaches)
│       ├── migration-phases/ 7-phase NDO migration plan
│       └── alternate-approach/ Alternate NDO migration approach
```

## VMware VMM Domain -- What Gets Created

Running `terraform apply` from `apic-vmware/` creates the full VMware integration stack:

| ACI Object | File | Description |
|------------|------|-------------|
| VLAN Pool | `access-policies.nac.yaml` | `vmm-vlan-pool` (dynamic, 3501-3967) |
| CDP Policy | `access-policies.nac.yaml` | `cdp-enabled` |
| LLDP Policy | `access-policies.nac.yaml` | `lldp-enabled` (receive + transmit) |
| LACP Policy | `access-policies.nac.yaml` | `lacp-active` |
| Port Channel Policy | `access-policies.nac.yaml` | `mac-pinning` |
| Link Level Policy | `access-policies.nac.yaml` | `10G` |
| VMware VMM Domain | `vmm-domain.nac.yaml` | `vmm-vcenter-rcc` (read-write, manages VDS) |
| vCenter Controller | `vmm-domain.nac.yaml` | `vcenter01` with credential policy |
| Virtual Distributed Switch | `vmm-domain.nac.yaml` | Created by ACI via `dvs_version: 6.6` |
| VDS Uplinks | `vmm-domain.nac.yaml` | `uplink1`, `uplink2` |
| AAEP | `access-policies.nac.yaml` | `vmm-aaep` linked to VMM domain |
| VPC Interface Policy Group | `access-policies.nac.yaml` | `vpc-vmm-hosts` |
| Leaf Interface Profile | `access-policies.nac.yaml` | `leaf-111-112-intprof` (ports 1-48) |
| Leaf Switch Profile | `access-policies.nac.yaml` | `leaf-111-112-prof` (nodes 111-112) |
| VRF | `tenant-epg-nac.nac.yaml` | `VRF-NAC` under tenant EUR |
| Bridge Domain | `tenant-epg-nac.nac.yaml` | `BD-NAC` with subnet |
| EPG | `tenant-epg-nac.nac.yaml` | `EPG-NAC` on `vmm-vcenter-rcc` (dynamic VLAN) |

## apic-vmware/

Terraform project that deploys VMware VMM domain access policies, the VMM domain with VDS, and attaches the RCC EPG to the VMM domain, directly on APIC (not through NDO).

Uses the `netascode/nac-aci` module (v0.7.0) with YAML data from `data/nac-aci-vmm/`.

| File | Purpose |
|------|---------|
| `main.tf` | nac-aci module config -- manages access policies, fabric policies, interface policies, and tenants |
| `providers.tf` | ACI provider -- connects to APIC via `apic_url`, `apic_username`, `apic_password` |
| `variables.tf` | Variable definitions for APIC connection |
| `terraform.tfvars.example` | Example variable values (copy to `terraform.tfvars` and fill in) |

### Before You Apply -- Update Placeholders

Edit `data/nac-aci-vmm/vmm-domain.nac.yaml` and replace:

| Placeholder | What to set |
|-------------|-------------|
| `hostname_ip: "CHANGE_ME"` | vCenter IP address or FQDN |
| `datacenter: "CHANGE_ME"` | vCenter datacenter name |
| `username: "CHANGE_ME"` | vCenter service account username |
| `password: "CHANGE_ME"` | vCenter service account password |
| `dvs_version: "6.6"` | Match your vSphere version (`6.5`, `6.6`, `7.0`, `8.0`) |

Edit `data/nac-aci-vmm/tenant-epg-nac.nac.yaml` and update:

| Placeholder | What to set |
|-------------|-------------|
| `ip: 10.0.0.1/24` | Actual gateway subnet for BD-NAC |

### Usage

```bash
cd ~/Documents/terraform_redesign_esg/aci-redesign/apic-vmware
cp terraform.tfvars.example terraform.tfvars   # fill in APIC URL and credentials
terraform init
terraform plan
terraform apply
```

## data/nac-aci-vmm/

YAML configs consumed by `apic-vmware/main.tf` via the `yaml_directories` parameter.

| File | Section | Purpose |
|------|---------|---------|
| `vmm-domain.nac.yaml` | `fabric_policies` | VMware VMM domain, vCenter controller, VDS creation, credential policies, uplinks |
| `access-policies.nac.yaml` | `access_policies` | VLAN pool (3501-3967), CDP/LLDP/LACP/link level policies, AAEP, VPC policy group, leaf profiles |
| `tenant-epg-nac.nac.yaml` | `tenants` | EUR tenant, VRF-NAC, BD-NAC (with subnet), EPG-NAC on VMM domain (dynamic VLAN) |

## data/blueprints/

NAC YAML reference blueprints for the ACI redesign. These use the `apic:` root key (nac-aci format, direct APIC). They document design patterns including tenant config, VRFs, BDs, EPGs, contracts, ESGs, FTDv firewall integration, DHCP relay, IP SLA, service graphs, and prefix leaking.

| File | Description |
|------|-------------|
| `blueprint-1.nac.yaml` | Base design -- tenant, VRFs, BDs, EPGs, contracts, FTDv, service graph, DHCP relay |
| `blueprint-2.nac.yaml` through `blueprint-9.nac.yaml` | Incremental design variations |
| `blueprint-10.nac.yaml` | Full design with all features |
| `blueprint-rcc-vmm-nac.nac.yaml` | EUR tenant, AppProf-RCC, EPG-NAC on VMM domain (template) |

## data/archive/

Archived NDO-format NAC configs (`ndo:` root key) used during the original migration planning. These are **reference only** and not actively deployed.

### migration-phases/

7-phase migration plan for transitioning to the new ACI design via NDO:

| Phase | File | Description |
|-------|------|-------------|
| 1 | `1-base-build.nac.yaml` | Sites (AEDCK/AEDCG), tenant EUR, schema AEDCE, VRFs, BDs, EPGs, subnets |
| 2 | `2-add-single-esg-for-all-epgs.nac.yaml` | Add ESG grouping all EPGs |
| 3 | `3-add-app-centric-migration.nac.yaml` | App-centric contract migration |
| 4 | `4-add-tighter-contracts.nac.yaml` | Tighten contract scope |
| 5 | `5-add-prefix-leaking-to-shared-l3out.nac.yaml` | Prefix leaking to shared L3Out |
| 6 | `6-add-ftdv.nac.yaml` | FTDv firewall integration |
| 7 | `7-insert-service-graph.nac.yaml` | Service graph insertion |

### alternate-approach/

4-phase alternate migration approach (phases 1-4 only).

## Related Workspace Folders

| Workspace Folder | Purpose |
|------------------|---------|
| LAB - IPv6 RCC (ndo-terraform) | IPv6 RCC infrastructure via direct Terraform HCL on NDO |
| LAB - IPv4 NAC (ndo_terraform) | Ansible/Python tools for fabric policies and static port bindings |
| LAB - IPv4 NAC Terraform (ndo_terraform_nac) | Full Terraform NAC project -- all NDO objects for IPv4 (schema_AEDCE.nac.yaml) |
| LAB - N5K Migration & Leaf Replacement | N5K migration and ACI leaf replacement toolkit |

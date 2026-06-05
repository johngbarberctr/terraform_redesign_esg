# Projects Listing — Mac DC workspaces

One-off reference. Lists every project across `~/DC/`: Mac path, git remotes,
purpose, and what it pushes where. Companion to `PROJECT_MAP.md`, which
focuses on CI/runners and file paths.

> **Heads-up on IPs in this document.** Lab APIC, NDO, and vCenter IPs shown
> below are point-in-time snapshots from when this file was written. Lab
> infrastructure gets re-IP'd periodically. The **operative** IPs for any
> given project are the values in that project's `terraform.tfvars`,
> `ndo.nac.yaml`, or `.env` file — not these tables. Always cross-check
> before relying on any IP listed here. As of 2026-05-04, the lab APICs are
> Site1 = `198.18.134.252`, Site2 = `198.18.134.253`.

---

## ACI projects

### 1. `terraform-esg` — IaC monorepo

|                            |                                                                                          |
| -------------------------- | ---------------------------------------------------------------------------------------- |
| **Mac path**               | `/Users/johbarbe/DC/ACI/terraform-esg/`                                                  |
| **Git remotes**            | `localhost:8080/root/terraform_redesign_esg` (GitLab), `github.com/johngbarberctr/terraform_redesign_esg` (origin) |
| **Cursor workspace label** | `LAB - ESG Terraform (ndo-terraform + aci-redesign)`                                     |
| **Purpose**                | Holds two distinct Terraform projects in one repo.                                       |

**Subproject `aci-redesign/`** -- the IPv4 redesign work.
Two Terraform roots:

| Root            | Owns                                                                                                              |
| --------------- | ----------------------------------------------------------------------------------------------------------------- |
| `apic-vmware/`  | APIC access/fabric policies, VMware VMM domain (one per fabric), MCP instance policy. Also the **ESG layer**: ANP `AppProf-AppCentric-V2` + `ESG-All-Internal-V2` (VRF-EUR-V2) + `ESG-All-DMZ-V2` (VRF-DMZ-V2), loaded from `data/nac-aci-shared/tenant-eur-esgs.nac.yaml` -- ESGs ride the `nac-aci@0.7.0` wrapper because `nac-ndo`/`mso` provider don't model `endpoint_security_groups`. |
| `ndo/`          | Tenant `EUR` (referenced), 2 VRFs (VRF-EUR-V2 / VRF-DMZ-V2 with vzAny+permit-all), 39 BDs, 39 EPGs across `AppProf-NetCentric-V2` (36) + `AppProf-DMZ-V2` (3). |

Six data dirs:

| Dir                              | Purpose                                                              |
| -------------------------------- | -------------------------------------------------------------------- |
| `data/nac-aci-site1/`            | Site1 lab access policy (lab simulator topology)                     |
| `data/nac-aci-site2/`            | Site2 lab access policy (lab simulator topology)                     |
| `data/nac-aci-shared/`           | cross-fabric APIC policy: nac-aci module toggles (`modules.nac.yaml`) AND the V2 ESG layer (`tenant-eur-esgs.nac.yaml` -- ANP `AppProf-AppCentric-V2` + 2 ESGs, loaded by both Site1 and Site2 modules) |
| `data/nac-aci-site1-prod/`       | Site1 **prod** access policy (Design A: UCS-FI direct attach, no vPC) |
| `data/nac-aci-site2-prod/`       | Site2 **prod** access policy (Design A)                              |
| `data/nac-ndo/`                  | NDO schema (`AFRICOM-V2`, template `Tenant_EUR_V2`) -- shared lab + prod |

Targets: lab APICs `198.18.134.253` / `198.18.134.254` and NDO `198.18.133.100`.

**Subproject `ndo-terraform/`** -- the IPv6 RCC NDO/MSO Terraform
(39 BDs/EPGs in `VRF-RCC`, schema `AFRICOM`). Lab-only via NDO. Helper scripts
(`generate_ipv6_bindings*.py`) generate static port bindings. Lives next to
`aci-redesign/` but is logically a separate stack.

**Other dirs**: `docs/` (architecture/reports for the IPv6 build),
`scripts/` (cross-project helpers), `backups/` (state snapshots),
`data/` (legacy/archived NAC YAML).

### 2. `ndo-terraform` (sibling folder) — IPv4 NAC ansible helper

|                            |                                                                                          |
| -------------------------- | ---------------------------------------------------------------------------------------- |
| **Mac path**               | `/Users/johbarbe/DC/ACI/ndo-terraform/`                                                  |
| **Git remotes**            | **none** (not a git repo -- files only)                                                  |
| **Cursor workspace label** | `LAB - IPv4 NAC`                                                                         |
| **Purpose**                | Old-style ansible+python tooling for IPv4 lab static-port-binding pushes against NDO.    |
| **Files**                  | `setup_fabric_policies_africom.yml` (ansible), `deploy_bindings_python_v2.py`, `selective_bindings_del.py`, `vault.yml`. |
| **Status**                 | Pre-NAC tooling. Superseded for the redesign by `terraform-esg/aci-redesign/scripts/deploy_bindings.py`. Keep around for IPv6 lab binding pushes that haven't been migrated to nac-ndo yet. |

### 3. `ndo-terraform-nac` — IPv6 RCC production NDO build

|                            |                                                                                          |
| -------------------------- | ---------------------------------------------------------------------------------------- |
| **Mac path**               | `/Users/johbarbe/DC/ACI/ndo-terraform-nac/`                                              |
| **Git remotes**            | `localhost:8080/root/ndo_terraform` (GitLab), `localhost:8080/Administrator/ndo_terraform` (origin) |
| **Cursor workspace labels**| `LAB - IPv4 NAC Terraform` (root) and `PROD - IPv6 RCC (136.215.4.96)` (sub-dir)         |
| **Purpose**                | NAC-style Terraform for NDO at multiple sites. Houses the canonical IPv6 RCC build under `136.215.4.96/` (39 BDs, 39 EPGs in `VRF-RCC`, L3Outs, External EPGs). |
| **Other layout**           | `data/`, `data-ipv6/`, `schemas/`, `ndo/`, plus a Robot Framework test harness (`log.html`, `report.html`, `output.xml`). |
| **Production target**      | NDO at `136.215.4.96`.                                                                   |
| **Note**                   | Confusingly similar name to `ndo-terraform` (item 2) -- entirely separate repos.          |

---

## NXOS projects

### 4. `n5k` (top-level) — N5K snake-bindings extraction & deployment

|                            |                                                                                          |
| -------------------------- | ---------------------------------------------------------------------------------------- |
| **Mac path**               | `/Users/johbarbe/DC/NXOS/n5k/`                                                           |
| **Git remotes**            | `localhost:8080/root/n5k_replacement` (GitLab), `github.com/johbarbe/n5k_replacement` (origin) |
| **Cursor workspace labels**| `LAB - N5K Migration & Leaf Replacement` (root) and `PROD - N5K Migration & Leaf Replacement` (sub-dir) |
| **Purpose**                | Pulls VLAN/PO/INT data from N5Ks (`APCK-D*-INT.txt`, `*-PO.txt`, `*-VL.txt`), processes it into NDO static bindings, and pushes to NDO. |
| **Tooling mix**            | ansible (`process_all_switches*.yml`, `configure_apic_fabric*.yml`, `get_active_*.yml`), Python (`deploy_bindings_python_v2.py`, `selective_bindings_del.py`), per-switch raw dump artefacts. |
| **GitLab CI**              | `.gitlab-ci.yml` at repo root drives validate / process-data / dry-run / deploy / remove on a shell runner (`apckw059aau0096`). |

### 5. `aci-lf-rplc` (LAB and PRODUCTION) — leaf-replacement bindings tool

|                            |                                                                                          |
| -------------------------- | ---------------------------------------------------------------------------------------- |
| **Mac paths**              | `/Users/johbarbe/DC/NXOS/n5k/Snake/LAB/aci-lf-rplc/` and `/Users/johbarbe/DC/NXOS/n5k/Snake/PRODUCTION/aci-lf-rplc/` |
| **Git remotes**            | sub-dirs of the `n5k_replacement` repo above -- same remotes                              |
| **Purpose**                | Successor to `n5k/` that replaces N5K-derived bindings with bindings sourced directly from an APIC EPG export (`epg_data.json`). |
| **Files**                  | `deploy_bindings_python.py`, `selective_bindings_del.py`, `process_data_LF.yml`, `epg_data.json`, `ansible.cfg`. |
| **RHEL counterpart**       | `~/aci-lf-rplc/` on the RHEL GitLab/runner host. The Mac→RHEL copy contract is just the `.gitlab-ci.yml` (see `PROJECT_MAP.md`). |
| **Status**                 | Out of scope for the IPv4 ACI redesign work -- do not edit during that effort.            |

---

## Cursor workspaces (.code-workspace files)

| Workspace        | File                                                                              | Folders mapped                                                                       |
| ---------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `ACI_LAB`        | `/Users/johbarbe/DC/ACI/terraform-esg/ACI_LAB.code-workspace`                     | terraform-esg, ndo-terraform-nac, sac-johbarbe-AFRICOM-terraform-nac-ndo, n5k, n5k/.../aci-lf-rplc   |
| `ACI_PRODUCTION` | `/Users/johbarbe/DC/ACI/terraform-esg/ACI_PRODUCTION.code-workspace`              | ndo-terraform-nac/136.215.4.96, n5k/Snake/PRODUCTION                                |

---

## What runs where

| Goal                                                | Project                | Path                                                              | Driver                                              |
| --------------------------------------------------- | ---------------------- | ----------------------------------------------------------------- | --------------------------------------------------- |
| Push IPv4 redesign to lab APICs (access/fabric/VMM) | aci-redesign           | `terraform-esg/aci-redesign/apic-vmware/`                         | `make plan && make apply`                           |
| Push IPv4 redesign tenant content to NDO            | aci-redesign           | `terraform-esg/aci-redesign/ndo/`                                 | `make plan && make apply` (then click Deploy in UI) |
| Push IPv4 EPG static bindings                       | aci-redesign           | `terraform-esg/aci-redesign/scripts/deploy_bindings.py`           | python after NDO deploy                             |
| Push IPv6 RCC tenant to lab NDO                     | ndo-terraform          | `terraform-esg/ndo-terraform/`                                    | terraform                                           |
| Push IPv6 RCC tenant to **prod** NDO                | ndo-terraform-nac      | `ndo-terraform-nac/136.215.4.96/`                                 | terraform                                           |
| Push N5K-derived bindings to NDO (legacy)           | n5k                    | `NXOS/n5k/`                                                       | ansible + `deploy_bindings_python_v2.py` (or CI)    |
| Push EPG-export-derived bindings (current)          | aci-lf-rplc            | `NXOS/n5k/Snake/{LAB,PRODUCTION}/aci-lf-rplc/`                    | ansible + `deploy_bindings_python.py`               |
| Push IPv4 lab fabric policies (legacy ansible flow) | ndo-terraform (sibling)| `ACI/ndo-terraform/`                                              | ansible                                             |

---

## GitLab projects (on RHEL `localhost:8080`)

| GitLab project                  | Local Mac path                                                            | Repo on RHEL                                |
| ------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------- |
| `root/terraform_redesign_esg`   | `terraform-esg/`                                                          | `~/Documents/terraform_redesign_esg`        |
| `root/ndo_terraform`            | `ndo-terraform-nac/`                                                      | `~/ndo_terraform_nac`                       |
| `root/n5k_replacement`          | `NXOS/n5k/` (and its `Snake/{LAB,PRODUCTION}/aci-lf-rplc` subdirs)        | `~/nxos/n5k/` and `~/aci-lf-rplc/`          |

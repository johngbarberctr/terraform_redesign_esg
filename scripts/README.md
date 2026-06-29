# scripts — Operational helpers

Operational Python tools for the ESG redesign and AFRICOM NIPR implementation.
None of these are run by Terraform itself — they are pre/post-deploy and
cutover utilities.

> **Not the same as `africom-aci-apic/scripts/`**, which contains Terraform
> shell helpers (`render-vmm-yaml.sh`, `auth-check.sh`, etc.) called during
> `make plan/apply`. This directory is for standalone Python operational tools.

For the canonical end-to-end deployment runbook see
[`../README_LAB.md`](../README_LAB.md). For the AFRICOM NIPR implementation
plan see [`../docs/AFRICOM/AFRICOM_Implementation_Plan.md`](../docs/AFRICOM/AFRICOM_Implementation_Plan.md).

---

## Script index

| Script | Purpose |
|--------|---------|
| `validate_fabric.py` | **AFRICOM NIPR Phase 0** — fabric health checks + optional APIC snapshot, NDO backup, schema export. Run before and after every implementation phase. See below. |
| `deploy_bindings.py` | Deploy V2 EPG static port bindings to NDO (PATCH-based, idempotent) |
| `dump_bindings.py` | Export existing NDO binding paths to JSON (seed file for `deploy_bindings.py`) |
| `check_fi_bindings_parity.py` | Verify FI binding manifest (`fi_epg_manifest.json`) matches the NDO V2 schema |
| `generate_fi_bindings.py` | Regenerate `fi_epg_manifest.json` from the NDO V2 schema |
| `deploy_bindings_rcc.py` | **Legacy / superseded by VMM** — deploys static port bindings for the IPv6 RCC tenant (variant of `deploy_bindings.py`; single-site, hardcoded template `L2_Stretched`, schema `AFRICOM`). The IPv6 RCC layer is now VMM-domain-based in `aci-ndo-ipv6/bds_epgs.tf`, so the hardcoded names reflect the pre-VMM era. |
| `check_rcc_bindings.py` | Verify RCC bindings |
| `get_epg_endpoints.py` | Pull per-EPG endpoint lists from APIC |
| `analyze_bd_mapping.py` | Analyse BD-to-EPG mappings in the redesign schema |
| `ndo_bd_egp_mappings.py` | Dump NDO BD↔EPG associations |
| `parse_ndo_backup.py` / `parse_ndo_backup_v2.py` | Parse NDO backup JSON for offline analysis |
| `generate_ipv6_bindings1/2.py` | Generate static port bindings for the IPv6 RCC layer |
| `clear_migration_state.py` | Reset migration state tracking (use with care) |
| `test_fi_bindings.py` | Unit tests for FI binding generation |

---

## validate_fabric.py — AFRICOM NIPR Phase 0

`validate_fabric.py` requires **no pip packages** — stdlib only.
All other scripts in this directory require a venv (see below).

### Quick reference

```bash
# Full Phase 0 — before a change window:
# Creates APIC snapshots, NDO backup, schema export, saves health baseline.
python3 scripts/validate_fabric.py \
  --phase0 \
  --artifacts-dir scripts/baseline/pre-phase1 \
  --label pre-phase1

# Health check only (read-only, safe any time):
python3 scripts/validate_fabric.py -o scripts/baseline/quick-check.json

# Post-change drift report:
python3 scripts/validate_fabric.py \
  --compare scripts/baseline/pre-phase1/baseline.json \
  -o scripts/baseline/post-phase1/baseline.json

# Skip NDO (when ND is unreachable):
python3 scripts/validate_fabric.py --skip-ndo
```

### Flags

| Flag | What it does |
|------|-------------|
| `--phase0` | Enable all three write actions (equivalent to `--snapshot --backup-ndo --export-schema`) |
| `--snapshot` | 0.1 — trigger APIC config snapshot on both sites |
| `--backup-ndo` | 0.2 — trigger NDO backup to the configured remote location |
| `--export-schema` | 0.6 — save AFRICOM NIPR schema JSON to `--artifacts-dir` |
| `--compare <file>` | Diff current results against a saved baseline |
| `--artifacts-dir <dir>` | Directory for schema export + baseline JSON (default: `scripts/baseline/<timestamp>/`) |
| `--output / -o <file>` | Override the baseline JSON output path |
| `--skip-ndo` | Skip all NDO checks and actions |
| `--label <string>` | Label used in snapshot/backup names (default: timestamp) |

### Credentials

All read from environment variables (same pattern as `deploy_bindings.py`):

```bash
export KELLEY_APIC_URL=https://...
export KELLEY_APIC_USERNAME=admin
export KELLEY_APIC_PASSWORD=...
export DELDIN_APIC_URL=https://...
export DELDIN_APIC_USERNAME=admin
export DELDIN_APIC_PASSWORD=...
export NDO_URL=https://...
export NDO_USERNAME=admin
export NDO_PASSWORD=...
```

In GitLab CI these are provided as masked variables. Set `PHASE0_FULL=true`
in the **Run Pipeline** dialog to activate the write actions in the
`phase0-validate-africom` job.

---

---

## Prerequisites — activate the venv

Two of the scripts here (`dump_bindings.py`, `deploy_bindings.py`) need
third-party packages (`requests`, `urllib3`, `PyYAML`); the other three
(`generate_fi_bindings.py`, `check_fi_bindings_parity.py`, `test_fi_bindings.py`)
are pure stdlib but it's simplest to activate the venv unconditionally.

The shared venv name differs by environment (see
[`../../README.md`](../../README.md) "One-time setup" for the full bootstrap):

| Environment | Venv path | Activate |
|---|---|---|
| Lab — laptop (Mac) | `~/dc_redesign` | `source ~/dc_redesign/bin/activate` |
| Production — RHEL 8 host | `~/ansvenv` | `source ~/ansvenv/bin/activate` |

If the venv doesn't exist yet, create it once (substitute the right name):

```bash
# Lab (laptop)
python3 -m venv ~/dc_redesign
source ~/dc_redesign/bin/activate
pip install requests urllib3 PyYAML

# Production (RHEL 8)
python3 -m venv ~/ansvenv
source ~/ansvenv/bin/activate
pip install requests urllib3 PyYAML
```

A bare `python3 ./deploy_bindings.py ...` against system Python typically
fails with `ModuleNotFoundError: No module named 'yaml'` (or `requests`).

---

## Recommended cutover sequence

This is the post-deploy bindings flow that runs once Terraform has provisioned
the redesign tenant tree (`aci-ndo/` apply + manual NDO UI deploy).
There are two paths — pick one based on which fabric topology you have:

### Path A — dump from the IPv6 RCC schema (lab default; requires `aci-ndo-ipv6/` already deployed)

1. `dump_bindings.py` — pull existing bindings from the IPv6 RCC schema
   (`AFRICOM` / `AppProf-AFR-PROD-V6`) into a JSON file matching `bindings.example.json`.
2. Review and edit the dumped JSON. Decide your VLAN strategy (see
   `dump_bindings.py` docstring; default strips VLAN, but `deploy_bindings.py`
   requires one).
3. `deploy_bindings.py current_bindings.json` — PATCH the bindings into NDO
   schema `AFRICOM-V2` / template `Tenant_EUR_V2`.
4. Click **Deploy** in the NDO UI to push the new `staticPorts` to the APICs.

### Path B — generate from FI topology (production default; `aci-ndo-ipv6/` not required)

1. `generate_fi_bindings.py` — read the prod schema + an FI VLAN map, emit
   `fi_bindings.json` containing all bindings on the four FI port-channels.
2. Review the JSON. Resolve any VLAN collisions reported in stderr.
3. `deploy_bindings.py fi_bindings.json` — PATCH the bindings into NDO
   schema `AFRICOM-V2` / template `Tenant_EUR_V2`.
4. Click **Deploy** in the NDO UI.

---

## `dump_bindings.py`

Read-only NDO REST client. Walks an existing schema's `staticPorts[]` and
emits them as a JSON file in the format `deploy_bindings.py` consumes. The
common usage is dumping `AFRICOM / AppProf-AFR-PROD-V6` (39 EPGs, IPv6 RCC redesign)
into a starter file for `AFRICOM-V2`.

> The dumper does not auto-rewrite EPG names. Source EPGs from
> `AFRICOM/AppProf-AFR-PROD-V6` come without the `-V2` suffix; the V2 redesign
> EPGs are suffixed (see `../docs/DESIGN.md` "Naming convention").
> Either pre-edit the bindings JSON to rename source EPGs to their `-V2`
> equivalents (e.g. `EPG-WEB-SVR` → `EPG-WEB-SVR-V2`) before pushing,
> or rely on the `--target-schema` parity warnings to surface mismatches
> for bulk fix-up.

### When to run it

Whenever you need to (re-)seed the bindings JSON. Typical cases:

- Initial cutover: dump from IPv6 schema to bootstrap V2 bindings.
- Drift check: dump the current `AFRICOM-V2` bindings and diff against your
  source-of-truth file.
- Migration: re-run after the IPv6 schema has been re-cabled.

### Defaults (lab-safe)

| Flag | Default | Why |
| --- | --- | --- |
| `--source-schema` | `AFRICOM` | The IPv6 RCC redesign schema in NDO. |
| `--source-anp`    | `AppProf-AFR-PROD-V6` | The single ANP holding all 39 IPv6 EPGs. |
| `--target-schema` | `AFRICOM-V2` | Used for validation (EPG name parity). Set `''` to skip. |
| `--exclude-leaves` | `101,102` | Border leaves -- L2 collection only in IPv6, not relevant for V2 EPGs. **See collision note below.** |
| `--leaves`        | (empty) | If set, INCLUDE-only filter. For the Kelley/Del-Din lab use `101,102` (the UCS-FI compute leaves; previously `152,153,119,191` from another customer). |

> **Leaf-number collision to resolve.** The UCS-FI compute leaves were renumbered
> to `101,102` to match the canonical FI design (`africom-aci-apic/`). But the
> `--exclude-leaves` default is *also* `101,102` ("border leaves"), which is a
> leftover from the old topology. Include and exclude can no longer both be
> `101,102`. Before running the examples below, confirm the real AFRICOM
> border-leaf node IDs and update `--exclude-leaves` accordingly (or drop the
> `--leaves` include filter if 101/102 are the only compute leaves).
| `--strip-vlan`    | on | V2 EPGs are VMM-dynamic (3501-3967); IPv6 VLANs (3001-3500) would be rejected by APIC. |
| `--dmz-epgs`      | `EPG-D64-PROXY-V2,EPG-FWEB-PROXY-V2,EPG-RWEB-PROXY-V2` | Routes those three to `AppProf-DMZ-V2`; everything else to `AppProf-NetCentric-V2`. (The third ANP, `AppProf-AppCentric-V2`, is APIC-direct and holds only the two Phase-2 ESGs -- never a binding target.) |

### Auth

Same multi-attempt flow as `deploy_bindings.py`. Reads `NDO_HOST` /
`NDO_USER` / `NDO_PASSWORD` from env, or accepts `--host` / `--username`
and prompts for the password.

### Usage

```bash
cd scripts
export NDO_HOST=<ndo-ip>
export NDO_USER=admin

# Preview only -- prints summary, sample bindings, EPG-parity warnings.
# NOTE: 101,102 are the UCS-FI compute leaves; set --exclude-leaves to the real
#       border-leaf node IDs first (see collision note above).
./dump_bindings.py --leaves 101,102 --exclude-leaves '' --dry-run

# Write the file (mode 0600).
./dump_bindings.py --leaves 101,102 --exclude-leaves '' --output current_bindings.json

# Keep VLANs in the output (NOT recommended for VMM-only target EPGs).
./dump_bindings.py --keep-vlan --output bindings_with_vlan.json
```

The summary prints: total bindings, breakdown by site / port type / leaf,
EPGs in the source missing from the target schema (will be silently dropped
by `deploy_bindings.py`), and target EPGs with zero source bindings (likely
need manual ports added).

## `deploy_bindings.py`

Posts static port bindings (`staticPorts`) onto EPGs in the NDO schema
`AFRICOM-V2` (template `Tenant_EUR_V2`). Forked from
`/Users/johbarbe/DC/NXOS/n5k/deploy_bindings_python_v2_prod.py` with the
default schema set to `AFRICOM-V2` and the production NDO host removed.

Why it exists: `nac-ndo` does not model `staticPorts` arrays in YAML, so
the Terraform-driven schema build creates the EPG shells but cannot push the
per-port bindings. This script PATCHes them in via the NDO REST API.

### When to run it

After:

1. The `ndo/` Terraform root has applied the `AFRICOM-V2` schema (template
   `Tenant_EUR_V2`) into NDO.
2. You have clicked **Deploy to sites** in the NDO UI for that template, so
   the EPGs exist on Kelley and Del-Din.

Then (and only then) does it make sense to push static-port bindings on top
of those EPGs.

After this script finishes, click **Deploy** in the NDO UI again to push the
new staticPorts down to the APICs.

### Auth

The script tries multiple auth flows automatically:

1. Nexus Dashboard 4.x `/login` with `domain=local`, then `domain=DefaultAuth`.
2. Standalone NDO/MSO `/api/v1/auth/login` with and without `domain=local`.

The first one that returns a token wins. You don't have to know which NDO
flavour you have -- the script figures it out. If all attempts fail it
prints what it tried and exits 1.

Password sources (mutually exclusive):

- **Ansible vault (default).** Reads `vault.yml` (key `ndo_password`)
  decrypted with `vault_pass.txt`. Both files must live in the working
  directory you run the script from. Ansible CLI required.
- **`--no-vault`.** Reads `ndo_password` straight from the bindings JSON.
  Simpler for lab work; **never commit a JSON file with a real password**.

### Bindings JSON shape

See [`bindings.example.json`](bindings.example.json). Top-level keys:

| Key | Required | Notes |
| --- | --- | --- |
| `ndo_host` | yes | IP or hostname of the NDO / Nexus Dashboard. The script refuses to guess. Override via env: `NDO_HOST=...`. |
| `ndo_username` | no | Defaults to `admin`. |
| `ndo_password` | only with `--no-vault` | Plaintext password. Use vault for anything beyond a throwaway lab. |
| `schema_name` | no | Defaults to `AFRICOM-V2`. Pass `--schema-name` on the CLI to override per-run. |
| `static_port_bindings` | yes | List of binding dicts. |

Each binding dict:

| Field | Notes |
| --- | --- |
| `site` | NDO site name. Must be `Kelley` or `Del-Din` for the V2 redesign. |
| `epg_name` | EPG name. Must already exist in the deployed schema (the script skips bindings for unknown EPGs and logs them). |
| `vlan` | Encap VLAN ID (integer). |
| `path` | APIC topology path. Regular: `topology/pod-1/paths-<leaf>/pathep-[<port>]`. vPC: `topology/pod-1/protpaths-<leaf-pair>/pathep-[<vpc-policy-group>]`. |
| `deployment_immediacy` | `immediate` or `lazy`. Defaults to `immediate`. |
| `mode` | `regular`, `native`, or `untagged`. Defaults to `regular`. |
| `port_type` / `path_type` | Optional explicit override (`port`, `dpc`, `vpc`). The script auto-detects from the path otherwise. |

### Usage

```bash
cd scripts

# Lab: read everything from the JSON, no vault.
./deploy_bindings.py bindings.json --no-vault --dry-run
./deploy_bindings.py bindings.json --no-vault

# Production-style: vault.yml + vault_pass.txt in the cwd.
./deploy_bindings.py bindings.json --dry-run
./deploy_bindings.py bindings.json

# Override the schema name without editing the JSON.
./deploy_bindings.py bindings.json AFRICOM-V2 --no-vault
```

`--dry-run` prints exactly what it would PATCH and never makes a write call.
Always run `--dry-run` first against a new bindings file.

### What it does NOT do

- Does not create or modify EPGs, BDs, VRFs, contracts, or VMM domain
  bindings. Those come from the Terraform schema (`../data/nac-ndo/`).
- Does not deploy templates to sites. That's a manual click in the NDO UI
  (or `deploy_templates = true` in `../ndo/main.tf`).
- Does not configure access policies, AAEP, VPC policy groups, or anything
  on the APIC interface side. Those are APIC-direct in `../aci-apic/`.
- Does not delete bindings. It is additive only -- it skips bindings that
  already exist on NDO. To remove, edit in the NDO UI or extend the script
  with `op: remove` patches.

### Lineage

| Path | Purpose |
| --- | --- |
| `/Users/johbarbe/DC/NXOS/n5k/deploy_bindings_python_v2_prod.py` | Original. Production migration tool, schema `AFRICOM`. |
| `/Users/johbarbe/DC/NXOS/n5k/deploy_bindings_python_v2_lab.py` | Lab variant of the n5k tool. |
| `scripts/deploy_bindings_rcc.py` | The IPv6-era equivalent (single-site, hardcoded template `L2_Stretched`, schema `AFRICOM`). Legacy — IPv6 RCC layer is now VMM-domain-based. |
| `scripts/deploy_bindings.py` | This file. V2 redesign default schema, host required from JSON. |

## `generate_fi_bindings.py`

Generates a UCS-FI static-port bindings JSON for `deploy_bindings.py` to
consume. Reads the EPG list from `../data/nac-ndo/schema-africom-v2.nac.yaml`
and emits one binding per (site, FI port-channel) tuple, hardcoded to the
Design A topology: `PC_FI_A` on leaf 101 (Kelley and Del-Din), `PC_FI_B`
on leaf 102 (Kelley and Del-Din). (Leaves were previously 152/153 Kelley,
119/191 Del-Din — placeholders from another customer; renumbered to the
AFRICOM fabric leaves 101/102, may change again.)

The schema parser also detects whether each EPG is VMM-bound (any
`vmware_vmm_domains:` block, or a `sites: *epg_sites_internal` anchor
reference). That feeds two operational modes:

| Flag | Mode | Output | Use case |
| --- | --- | --- | --- |
| _(none)_ | full / Approach 2 | All EPGs × 4 PCs (today: 156 bindings) | Production: VMM + static together. UCS FI breaks dynamic VMM learning, so static binds make VLANs land deterministically on the FI uplinks. |
| `--physical-only` | physical-only / Approach 1 | Only EPGs without VMM × 4 PCs (today: 12 bindings, covering `EPG-LB`, `EPG-LMR`, `EPG-VHOST-MGMT`) | Lab: VMM dynamic learning handles every VDS-backed EPG, only the physical-endpoint EPGs need static binds. |

See [main README → Step 4 → VLAN strategy](../README.md#step-4--push-static-port-bindings)
for the full rationale.

### `--output-manifest`

Writes a sanitized JSON manifest alongside the bindings file. The
manifest contains the EPG list, the chosen mode, and the schema YAML
path — no creds, no VLANs, safe to commit. CI uses this to detect
schema/binding drift via `check_fi_bindings_parity.py`.

```bash
cd scripts

# Production default:
./generate_fi_bindings.py \
    --vlan-map         fi_vlan_map.json \
    --output           fi_bindings.json \
    --output-manifest  fi_epg_manifest.json

# Lab (physical-only):
./generate_fi_bindings.py --physical-only \
    --output           fi_bindings.json \
    --output-manifest  fi_epg_manifest.json
```

`fi_bindings.json` is mode 0600 and not committed. `fi_epg_manifest.json`
is committed.

## `check_fi_bindings_parity.py`

CI-side guard that fails if `fi_epg_manifest.json` and the schema YAML
have drifted apart. Exit codes:

* `0` — parity (schema and manifest agree under the manifest's mode)
* `1` — drift (EPG missing from manifest, or manifest references EPG not
  in schema)
* `2` — structural error (manifest missing, malformed JSON, invalid mode)

```bash
# Defaults pick up the schema and manifest in their conventional paths:
./check_fi_bindings_parity.py
```

The `parity-check-fi-bindings` job in `.gitlab-ci.yml` runs this on every
MR that touches the schema, the generator, the parity script, or the
manifest itself. A merge cannot land if drift is detected. Stray VMM
EPGs in a `physical-only` manifest produce a warning but pass — that
just means the operator opted into Approach 2 for those EPGs.

## `test_fi_bindings.py`

`unittest` suite covering the schema parser (VMM detection across
inline / anchor-defining / anchor-referencing patterns), the
`--physical-only` filter, and the parity checker (drift in both
directions, mode-specific semantics, structural errors). Includes a
sanity check against the real schema (39 EPGs, 36 VMM, 3 physical) and
a parity check against the committed manifest, so a local run surfaces
drift the same way CI does.

```bash
cd scripts
python3 -m unittest test_fi_bindings -v
```

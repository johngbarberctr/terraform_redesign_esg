# aci-redesign / scripts

Operational helpers for the IPv4 redesign. None of these are run by Terraform
itself -- they are post-deploy / cutover utilities.

## Recommended cutover sequence

1. `dump_bindings.py`  -- pull existing bindings from the IPv6 RCC schema
   (`AEDCE` / `AppProf-RCC`) into a JSON file matching `bindings.example.json`.
2. Review and edit the dumped JSON. Decide your VLAN strategy (see `dump_bindings.py`
   docstring; default strips VLAN, but `deploy_bindings.py` requires one).
3. `deploy_bindings.py current_bindings.json` -- PATCH the bindings into NDO
   schema `AEDCE-IPv4` / template `Tenant_EUR_IPv4`.
4. Click Deploy in the NDO UI to push the new staticPorts to the APICs.

## `dump_bindings.py`

Read-only NDO REST client. Walks an existing schema's `staticPorts[]` and
emits them as a JSON file in the format `deploy_bindings.py` consumes. The
common usage is dumping `AEDCE / AppProf-RCC` (39 EPGs, IPv6 RCC redesign)
into a starter file for `AEDCE-IPv4`.

### When to run it

Whenever you need to (re-)seed the bindings JSON. Typical cases:

- Initial cutover: dump from IPv6 schema to bootstrap IPv4 bindings.
- Drift check: dump the current `AEDCE-IPv4` bindings and diff against your
  source-of-truth file.
- Migration: re-run after the IPv6 schema has been re-cabled.

### Defaults (lab-safe)

| Flag | Default | Why |
| --- | --- | --- |
| `--source-schema` | `AEDCE` | The IPv6 RCC redesign schema in NDO. |
| `--source-anp`    | `AppProf-RCC` | The single ANP holding all 39 IPv6 EPGs. |
| `--target-schema` | `AEDCE-IPv4` | Used for validation (EPG name parity). Set `''` to skip. |
| `--exclude-leaves` | `101,102` | Border leaves -- L2 collection only in IPv6, not relevant for IPv4 EPGs. |
| `--leaves`        | (empty) | If set, INCLUDE-only filter. For the AEDCG/AEDCK lab use `152,153,119,191`. |
| `--strip-vlan`    | on | IPv4 EPGs are VMM-dynamic (3501-3967); IPv6 VLANs (3001-3500) would be rejected by APIC. |
| `--dmz-epgs`      | `EPG-D64-PROXY,EPG-FWEB-PROXY,EPG-RWEB-PROXY` | Routes those three to `AppProf-DMZ`; everything else to `AppProf-NetCentric`. |

### Auth

Same multi-attempt flow as `deploy_bindings.py`. Reads `NDO_HOST` /
`NDO_USER` / `NDO_PASSWORD` from env, or accepts `--host` / `--username`
and prompts for the password.

### Usage

```bash
cd aci-redesign/scripts
export NDO_HOST=<ndo-ip>
export NDO_USER=admin

# Preview only -- prints summary, sample bindings, EPG-parity warnings.
./dump_bindings.py --leaves 152,153,119,191 --dry-run

# Write the file (mode 0600).
./dump_bindings.py --leaves 152,153,119,191 --output current_bindings.json

# Keep VLANs in the output (NOT recommended for VMM-only target EPGs).
./dump_bindings.py --keep-vlan --output bindings_with_vlan.json
```

The summary prints: total bindings, breakdown by site / port type / leaf,
EPGs in the source missing from the target schema (will be silently dropped
by `deploy_bindings.py`), and target EPGs with zero source bindings (likely
need manual ports added).

## `deploy_bindings.py`

Posts static port bindings (`staticPorts`) onto EPGs in the NDO schema
`AEDCE-IPv4` (template `Tenant_EUR_IPv4`). Forked from
`/Users/johbarbe/DC/NXOS/n5k/deploy_bindings_python_v2_prod.py` with the
default schema set to `AEDCE-IPv4` and the production NDO host removed.

Why it exists: `nac-ndo` does not model `staticPorts` arrays in YAML, so
the Terraform-driven schema build creates the EPG shells but cannot push the
per-port bindings. This script PATCHes them in via the NDO REST API.

### When to run it

After:

1. The `ndo/` Terraform root has applied the `AEDCE-IPv4` schema (template
   `Tenant_EUR_IPv4`) into NDO.
2. You have clicked **Deploy to sites** in the NDO UI for that template, so
   the EPGs exist on AEDCG and AEDCK.

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
| `schema_name` | no | Defaults to `AEDCE-IPv4`. Pass `--schema-name` on the CLI to override per-run. |
| `static_port_bindings` | yes | List of binding dicts. |

Each binding dict:

| Field | Notes |
| --- | --- |
| `site` | NDO site name. Must be `AEDCG` or `AEDCK` for the IPv4 redesign. |
| `epg_name` | EPG name. Must already exist in the deployed schema (the script skips bindings for unknown EPGs and logs them). |
| `vlan` | Encap VLAN ID (integer). |
| `path` | APIC topology path. Regular: `topology/pod-1/paths-<leaf>/pathep-[<port>]`. vPC: `topology/pod-1/protpaths-<leaf-pair>/pathep-[<vpc-policy-group>]`. |
| `deployment_immediacy` | `immediate` or `lazy`. Defaults to `immediate`. |
| `mode` | `regular`, `native`, or `untagged`. Defaults to `regular`. |
| `port_type` / `path_type` | Optional explicit override (`port`, `dpc`, `vpc`). The script auto-detects from the path otherwise. |

### Usage

```bash
cd aci-redesign/scripts

# Lab: read everything from the JSON, no vault.
./deploy_bindings.py bindings.json --no-vault --dry-run
./deploy_bindings.py bindings.json --no-vault

# Production-style: vault.yml + vault_pass.txt in the cwd.
./deploy_bindings.py bindings.json --dry-run
./deploy_bindings.py bindings.json

# Override the schema name without editing the JSON.
./deploy_bindings.py bindings.json AEDCE-IPv4 --no-vault
```

`--dry-run` prints exactly what it would PATCH and never makes a write call.
Always run `--dry-run` first against a new bindings file.

### What it does NOT do

- Does not create or modify EPGs, BDs, VRFs, contracts, or VMM domain
  bindings. Those come from the Terraform schema (`../data/nac-ndo/`).
- Does not deploy templates to sites. That's a manual click in the NDO UI
  (or `deploy_templates = true` in `../ndo/main.tf`).
- Does not configure access policies, AAEP, VPC policy groups, or anything
  on the APIC interface side. Those are APIC-direct in `../apic-vmware/`.
- Does not delete bindings. It is additive only -- it skips bindings that
  already exist on NDO. To remove, edit in the NDO UI or extend the script
  with `op: remove` patches.

### Lineage

| Path | Purpose |
| --- | --- |
| `/Users/johbarbe/DC/NXOS/n5k/deploy_bindings_python_v2_prod.py` | Original. Production migration tool, schema `AEDCE`. |
| `/Users/johbarbe/DC/NXOS/n5k/deploy_bindings_python_v2_lab.py` | Lab variant of the n5k tool. |
| `/Users/johbarbe/DC/ACI/terraform-esg/scripts/deploy_bindings_rcc.py` | The IPv6-era equivalent (single-site, hardcoded template `L2_Stretched`, schema `AEDCE`). |
| `aci-redesign/scripts/deploy_bindings.py` | This file. IPv4 redesign default schema, host required from JSON. |

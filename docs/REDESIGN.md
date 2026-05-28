# aci-redesign

> **For deployment:** the canonical end-to-end runbook is **[`../README_LAB.md`](../README_LAB.md)**.
> **For design rationale, object inventory, and BD/EPG model:** see **[`DESIGN.md`](DESIGN.md)**.
> **For per-stack details:** each subdirectory has its own `README.md` (reference) and `README_LAB.md` (lab daily-driver).

This directory holds the **V2 (consolidated) tenant redesign** — four pieces
that together provision a 2-VRF tenant tree (`VRF-EUR-V2` + `VRF-DMZ-V2`)
with 39 BDs/EPGs across the AEDCG and AEDCK ACI fabrics. Tenant-scoped
objects carry a `-V2` suffix so the redesign coexists with the legacy
`AEDCE` schema in tenant `EUR` during the parallel-run period; see
[`DESIGN.md` → Naming convention](DESIGN.md#naming-convention).

## Subdirectories

| Path | What it is | Where to read |
|------|------------|---------------|
| `apic-vmware/` | APIC-direct Terraform root (lab): access/fabric policies, MCP, VMware VMM domains for both fabrics | [`apic-vmware/README.md`](apic-vmware/README.md), [`README_LAB.md`](apic-vmware/README_LAB.md) |
| `apic-vmware-prod/` | APIC-direct Terraform root (prod, Design A: UCS-FI direct attach) | [`apic-vmware-prod/README.md`](apic-vmware-prod/README.md) |
| `ndo/` | NDO-managed Terraform root: schema `AEDCE-V2`, single template `Tenant_EUR_V2` | [`ndo/README.md`](ndo/README.md), [`README_LAB.md`](ndo/README_LAB.md) |
| `scripts/` | Python tools for static port binding push (`dump_bindings.py`, `deploy_bindings.py`, `generate_fi_bindings.py`) | [`scripts/README.md`](scripts/README.md) |
| `data/` | Shared NAC YAML inputs (per-fabric + shared + NDO schema) | small per-folder notes; details in `DESIGN.md` |

## Two-root architecture

The IPv4 redesign is split across **two Terraform roots** that each own one
control plane:

| Root              | Control plane | Owns                                                                                  |
| ----------------- | ------------- | ------------------------------------------------------------------------------------- |
| `apic-vmware/`    | APIC (per fabric, two providers via aliases) | Access/fabric policies (leaf profiles, AAEP, VPC, VLAN pools), MCP instance policy, VMware VMM domain. |
| `ndo/`            | NDO (one Multi-Site control plane)           | Tenant `EUR`, VRFs, filter `Any`, contracts, all 39 stretched BDs, ANPs, EPGs, EPG-to-VMM-domain bindings. |

Why split: ACI tenant policy belongs in NDO when there's more than one site;
APIC-side fabric infrastructure is per-fabric and not modelable in NDO. So
we drive each layer from the right tool and keep the two roots independent
of each other. Full design rationale is in [`DESIGN.md`](DESIGN.md).

There's also a foundational dependency outside this repo: `terraform-esg/
aci-redesign/ndo/`'s `AEDCE-V2` schema cross-references the `Any` filter
defined in schema `AEDCE / VRF_Template`, which is built by the sibling repo
`~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/`. That sibling repo is **Phase 1** of the
runbook in [`../README_LAB.md`](../README_LAB.md); skip it and `terraform
plan` against `ndo/` will fail to resolve the cross-schema reference.

---

## Production cutover runbook

This section is the operational checklist for cutting AEDCG + AEDCK over
from the legacy IPv6/N5K-fronted design to the IPv4 redesign on Design A
(UCS-FI direct attach). It assumes the lab cutover has already succeeded
(i.e. all phases in [`../README_LAB.md`](../README_LAB.md) ran cleanly
against the lab) and that all the YAML changes have merged to `main`.

> **NOTE.** Production cutover is a coordinated change that spans the
> network team (this repo), the UCS team (FI uplink moves), and the
> virtualisation team (VDS uplink portgroups in vCenter). Schedule a
> maintenance window and have a rollback decision-maker on the bridge.

### Scope summary

| Layer | What changes | Source of truth |
| --- | --- | --- |
| APIC access/fabric policies | New `fi-static-vlan-pool`, `fi-aaep`, `phys-fi-domain`, `PC_FI_A` / `PC_FI_B` policy groups, leaf 152/153 (AEDCG) and 119/191 (AEDCK) split between VMM ports (8-48) and FI uplinks (eth1/6, eth1/7), per-fabric VMM domain (`APCG-VDS1`, `APCK-VDS1`). | `apic-vmware-prod/` (Terraform) reading `data/nac-aci-{aedcg,aedck}-prod/`. |
| APIC tenant tree (VRFs/BDs/EPGs/contracts) | Tenant `EUR`: 2 VRFs (`VRF-EUR-V2`, `VRF-DMZ-V2`), 39 BDs (suffixed `-V2`), 39 EPGs (suffixed `-V2`), vzAny + 2 cross-VRF contracts, EPGs bound to per-fabric VMM domains. | `ndo/` (Terraform) reading `data/nac-ndo/schema-aedce-v2.nac.yaml`. NDO pushes to both APICs. |
| Static port bindings (non-VMM EPGs) | `EPG-LB-V2`, `EPG-LMR-V2`, `EPG-VHOST-MGMT-V2` plus any prod bare-metal endpoints. | `scripts/deploy_bindings.py` reading a curated JSON file. |
| L3Outs / external EPGs | **No change in this cutover.** They remain in the legacy IPv6 schema and continue to attach to VRFs by name; both schemas share the same VRF objects on the APICs. | `~/DC/ACI/terraform-esg/ndo-terraform-ipv6/` (legacy IPv6 layer). |
| UCS / vCenter | FI uplinks physically re-cabled from N5K to ACI leaves; ESXi host VDS uplinks moved to the new APIC-managed `APCG-VDS1` / `APCK-VDS1`. | UCS team + virtualisation team. Out of scope for this repo. |

### Pre-flight (T-7 days)

1. **APIC backup snapshot, both fabrics.** From each APIC's GUI:
   `Admin → Import/Export → Configuration → Export Policies → Create Configuration Export Policy → Configure JSON, full snapshot, Now.`
   Confirm the snapshot landed and store the artefact ID. This is the
   rollback target.
2. **NDO snapshot.** `Operations → Backup` in NDO. Note the timestamp.
3. **vCenter snapshot.** Export VDS configuration for `APCG-VDS1` and
   `APCK-VDS1`.
4. **Generate the production bindings JSON.**
   ```bash
   # Activate the shared venv first (requests / urllib3 / PyYAML).
   # Production cutover runs from the RHEL 8 host, where the venv is named
   # ~/ansvenv (NOT ~/dc_redesign, which is the laptop name).
   # Bootstrap is in ../../README.md "One-time setup".
   source ~/ansvenv/bin/activate

   cd aci-redesign/scripts
   export NDO_HOST=<prod-ndo-ip>
   export NDO_USER=admin
   ./dump_bindings.py \
       --source-schema AEDCE \
       --source-anp    AppProf-NetCentric \
       --target-schema AEDCE-V2 \
       --leaves        152,153,119,191 \
       --keep-vlan \
       --output prod_bindings.json
   ```
   Read-only against prod NDO. Review the summary it prints (binding
   totals, EPG-parity warnings, target EPGs with zero bindings). Resolve
   VLAN collisions (multiple legacy EPGs landing on the same `(path,
   target-EPG)`) before proceeding — pick a winner per tuple.
5. **Run `terraform plan` against production end-to-end.**
   ```bash
   # Production APIC root
   cd aci-redesign/apic-vmware-prod
   make auth-check                 # confirm both APIC creds work
   make plan                       # renders VMM YAML for both fabrics, then plans
   #   - review plan.txt -- expect CREATE for fi-static-vlan-pool, fi-aaep,
   #     PC_FI_A/B policy groups, leaf-{152,153,119,191}-fi-intprof, the new
   #     leaf-*-prof switch profiles, and APCG/APCK-VDS1 VMM domains.
   #   - any DESTROY here is a red flag; stop and investigate.

   # NDO redesign root
   cd ../ndo
   make auth-check
   make plan
   #   - expect CREATE for schema AEDCE-V2, template Tenant_EUR_V2,
   #     2 VRFs, 39 BDs, 2 ANPs, 39 EPGs, 2 contracts (all -V2).
   #   - DELETE on any pre-existing IPv6 schema is a bug; this root only
   #     manages AEDCE-V2.
   ```
6. **Verify cabling and UCS plan.** The UCS team must confirm:
   - FI-A is currently single-homed to **leaf 152 (AEDCG)** / **leaf 119 (AEDCK)** through what will become `eth1/6`.
   - FI-B is single-homed to **leaf 153 (AEDCG)** / **leaf 191 (AEDCK)** through `eth1/7`.
   - LACP is configured **mac-pin** on the FI vNIC templates (matches `port_channel_policies: mac-pinning` in the prod data dirs). Note: the **lab** data dirs (`nac-aci-aedcg/`, `nac-aci-aedck/`) use `lacp-active` instead of `mac-pinning` for the FI IPGs — if running against the lab, the FI vNIC templates should match `active` mode.
   - If port assignments differ in production, edit `data/nac-aci-aedcg-prod/access-policies.nac.yaml` (`leaf_interface_profiles` sections) and `data/nac-aci-aedck-prod/access-policies.nac.yaml` BEFORE running `make plan`. **Never commit a plan you didn't review against the cabling worksheet.**
7. **Check `fi-static-vlan-pool` against today's NDO state.** The pool was
   sourced 2026-04-29. If the cutover slips by more than ~1 week, re-pull
   live VLANs from NDO and diff:
   ```bash
   curl -k -sS -u "$NDO_USER:$NDO_PASS" \
        "https://$NDO_HOST/mso/api/v1/schemas?name=AEDCE" \
       | jq '... | .staticPorts[] | .vlan' | sort -un > /tmp/vlans_live.txt
   ```
   Add any new VLANs to both prod data files, rerun `make plan`, get an MR
   review.
8. **Confirm cleanup target.** If production APICs still have a legacy VMM
   domain (e.g. `vmm-vcenter-rcc`) with dangling `fvRsDomAtt`, decide:
   remove it during the window via `make cleanup-old-vmm OLD_DOMAIN=<legacy-name>`,
   or leave it and let it become orphan. The cleanup script is idempotent
   and skips if the domain is already absent.

### Cutover sequence (T-0)

> **Communication order.** Start with the network change, then the UCS
> re-cable, then vCenter VDS uplink moves. Each stage is reversible until
> the previous stage's "Verify" step has passed.

#### Stage 1 — APIC access/fabric policies (no traffic impact yet)

```bash
cd aci-redesign/apic-vmware-prod

# Optional pre-step: clear any stale legacy VMM domain.
OLD_DOMAIN=vmm-vcenter-rcc make cleanup-old-vmm        # both fabrics, idempotent

# Apply both fabrics in one go.
make plan                                              # final review
make apply                                             # applies plan.tfplan
```

**Verify:**

- APIC GUI on each fabric: `Fabric → Access Policies → Pools → VLAN → fi-static-vlan-pool` exists with the expected ranges.
- `fi-aaep` exists and references both `phys-fi-domain` and `APCG-VDS1` / `APCK-VDS1`.
- `Fabric → Access Policies → Switches → Leaf Switches → Profiles → leaf-152-prof` (and `153`, `119`, `191`) each contain the new FI interface profile.
- No new APIC faults of `severity ≥ minor` other than the expected "interface down" on the FI uplink ports (which haven't been wired yet).

This stage adds new policies. It does **not** modify existing VMM
connectivity to ESXi hosts.

#### Stage 2 — Tenant tree push via NDO

```bash
cd aci-redesign/ndo
make plan
make apply
```

Then in NDO UI:
`Application Management → Schemas → AEDCE-V2 → Tenant_EUR_V2 → Deploy to sites`.
Confirm AEDCG and AEDCK both show "Deployed".

**Verify:**

- APIC GUI on each fabric: `Tenants → EUR → Application Profiles → AppProf-NetCentric-V2 / AppProf-DMZ-V2 → 39 EPGs` present (36 + 3).
- Each EPG shows the per-fabric VMM domain bound to it (`APCG-VDS1` on AEDCG, `APCK-VDS1` on AEDCK), with `Resolution Immediacy = Immediate`.
- vCenter: 39 port-groups under each VDS, named `EUR|...`. Should match the lab pattern.
- 3 EPGs (`EPG-LB-V2`, `EPG-LMR-V2`, `EPG-VHOST-MGMT-V2`) intentionally have **no** VMM bindings; they will land via Stage 3.

#### Stage 2b — ESG layer (re-apply `apic-vmware-prod/`)

Now that the EPGs in `AppProf-NetCentric-V2` and `AppProf-DMZ-V2` exist on each APIC, the ESG selectors in `data/nac-aci-shared/tenant-eur-esgs.nac.yaml` finally have something to match. Re-apply the APIC-direct root:

```bash
cd aci-redesign/apic-vmware-prod
make plan      # expect: 1 ANP (AppProf-AppCentric-V2) + 2 ESGs (ESG-All-Internal-V2, ESG-All-DMZ-V2) + ~78 epg_selector resources, per fabric
make apply
```

vzAny+permit-all on both VRFs (set in Stage 2's NDO schema) makes this purely additive — endpoints get classified into ESGs but reachability does not change.

**Verify:**

- APIC GUI on each fabric: `Tenants → EUR → Application Profiles → AppProf-AppCentric-V2 → Endpoint Security Groups` shows `ESG-All-Internal-V2` (in `VRF-EUR-V2`) and `ESG-All-DMZ-V2` (in `VRF-DMZ-V2`).
- For each ESG, `Operational → Endpoints` lists endpoints; counts should equal the sum of the corresponding EPG endpoint counts.
- Spot-check 2-3 endpoints — they appear under both their original EPG (`AppProf-NetCentric-V2/EPG-…-V2` or `AppProf-DMZ-V2/EPG-…-V2`) and an ESG.

#### Stage 3 — Static port bindings

```bash
# Re-activate the venv if you closed the shell since Pre-flight step 4.
# (Production cutover runs from the RHEL 8 host -- venv is ~/ansvenv there,
#  not ~/dc_redesign which is the laptop name.)
source ~/ansvenv/bin/activate

cd aci-redesign/scripts
./deploy_bindings.py prod_bindings.json --no-vault --dry-run    # final review
./deploy_bindings.py prod_bindings.json --no-vault              # PATCH NDO
```

Then in NDO UI: re-deploy the `Tenant_EUR_V2` template (same path as
Stage 2) so the new `staticPorts[]` push to the APICs.

**Verify:**

- APIC GUI: pick three sample bindings from `prod_bindings.json`; in each EPG's "Static Ports" tab, confirm the leaf/port/VLAN matches.
- Sample one bare-metal endpoint (e.g. an F5 BIG-IP behind `EPG-LB`); confirm L2 connectivity.

#### Stage 4 — UCS / vCenter physical move

This is run by the UCS team and the vSphere admin, **not** Terraform. The
required changes:

1. UCS: re-cable FI-A uplink from current N5K port to ACI leaf-152 (AEDCG) / leaf-119 (AEDCK) on `eth1/6`. Same for FI-B → leaf-153 / leaf-191 on `eth1/7`. Confirm `port-channel summary` on both FIs shows the bundle up with the new uplink.
2. vCenter: for each ESXi host behind a moved FI, migrate the VDS uplinks from the legacy VDS to `APCG-VDS1` / `APCK-VDS1`. Use **Migrate VMs to another network** in the VDS UI to drop VMs onto the new port-groups (named per the redesign EPGs).

**Verify:**

- APIC GUI: `Fabric → Inventory → <leaf> → Interfaces → Physical → eth1/6` shows `oper-state = up` on AEDCG-152 and AEDCK-119 (and `eth1/7` up on -153/-191).
- vCenter: VMs are now on port-groups whose names match redesign EPGs.
- `fvCEp` count on the new EPGs grows as VMs are migrated.

#### Stage 5 — Decommission

Once Stages 1–4 are stable for **at least 24 hours** with no traffic
anomalies:

- Remove the legacy IPv6 EPG-to-VMM bindings from the legacy schema (in `~/DC/ACI/terraform-esg/ndo-terraform-ipv6/` if any are still around) — coordinate with the legacy schema owner.
- Decommission the N5K-fronted policy on the legacy schema only after the UCS team confirms no FI is still uplinked to N5K.

### Rollback

If any verify step fails irrecoverably, abort and restore.

| If you stopped after... | Rollback action |
| --- | --- |
| Stage 1 (APIC policy push) | `cd aci-redesign/apic-vmware-prod && make destroy` (or use `apply-aedcg`/`-aedck` `-destroy` for one fabric only). All adds were additive; no existing object on the APIC was overwritten. Faults clear in <60s. |
| Stage 2 (NDO tenant push) | NDO UI: `Tenant_EUR_V2 → Undeploy from sites` for both AEDCG and AEDCK. Then `cd aci-redesign/ndo && make destroy` to remove the schema from NDO. Legacy IPv6 schema is unaffected (separate state, separate schema name). |
| Stage 3 (static bindings) | NDO UI: hand-remove bindings on the 3 affected EPGs, then re-deploy. `deploy_bindings.py` is additive only and does not auto-undo. |
| Stage 4 (UCS / vCenter physical) | UCS team re-cables FIs back to the N5K. vCenter admin migrates VMs back to the legacy VDS / port-groups. ACI-side policies stay in place; they're harmless if no port is up. |
| Catastrophic | Restore APIC config from the snapshot taken in Pre-flight Step 1. Restore NDO from Step 2. This is the last resort; it nukes any other concurrent change made during the window. |

### Post-cutover (T+1 day)

1. New APIC config-export snapshot on both fabrics.
2. New NDO snapshot.
3. Fault sweep on both APICs: anything `severity ≥ critical` that wasn't there pre-cutover gets a ticket.
4. Diff `prod_bindings.json` against fresh `dump_bindings.py` output to confirm no drift was introduced by hand.
5. Schedule the Phase-3 design ticket: per-zone ESG splits (e.g. `ESG-AIM-V2`, `ESG-AIS-V2`, `ESG-DMZ-Web-V2`) with `tag_selectors` driven by vCenter custom-attributes. The Phase-2 lift-and-shift ESGs (`ESG-All-Internal-V2`, `ESG-All-DMZ-V2`) are the rolling baseline — Phase 3 trims their `epg_selectors` and adds `tag_selectors` additively. See `DESIGN.md` → "Phase 2 deploy playbook" and the header of `data/nac-aci-shared/tenant-eur-esgs.nac.yaml` for the upgrade idiom. Other follow-ups: GEF/Transport handling, and any IPv4 redesign-specific L3Outs (when `nac-ndo` exposes the cross-VRF model the V2 design needs).

---

## Where this fits in the wider deployment

The runbook in [`../README_LAB.md`](../README_LAB.md) is the canonical
source. Briefly:

1. `~/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/` — foundational NDO build (tenant `EUR`, schema `AEDCE`, 5 templates, 812 prod bindings)
2. NDO UI: deploy 5 `AEDCE` templates in strict order
3. `apic-vmware/` — APIC fabric/VMM (this directory's lab Terraform root)
4. `ndo/` — V2 redesign tenant tree (this directory's NDO Terraform root)
5. `~/DC/ACI/terraform-esg/ndo-terraform-ipv6/` — IPv6 RCC layer (optional, only if Phase 6 Path A)
6. `scripts/deploy_bindings.py` — static port bindings push
7. Verify on APIC + vCenter

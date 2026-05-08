#!/usr/bin/env python3
"""
generate_fi_bindings.py -- Generate UCS-FI static port bindings JSON
================================================================================

Produces a `bindings.json` (shape: see ``bindings.example.json``) that pushes
each EPG in an NDO schema YAML onto the four UCS-FI port-channels of the
Design A redesign, ready to be PATCHed into NDO via ``deploy_bindings.py``.

Source of truth for the FI topology (Design A, single-homed PCs):

    aci-redesign/data/nac-aci-aedcg-prod/access-policies.nac.yaml lines 11-14, 202-243
        AEDCG: PC_FI_A on Leaf-152 eth1/6, PC_FI_B on Leaf-153 eth1/7

    aci-redesign/data/nac-aci-aedck-prod/access-policies.nac.yaml lines 13-14, 186-226
        AEDCK: PC_FI_A on Leaf-119 eth1/6, PC_FI_B on Leaf-191 eth1/7

These four port-channels are single-homed (one leaf each), so the binding
topology path is ``topology/pod-1/paths-<leaf>/pathep-[PC_FI_<X>]`` and the
NDO port type is ``dpc`` (direct port-channel), NOT ``vpc``.

Why this script exists
----------------------

The ``netascode/nac-ndo`` Terraform module does not model ``staticPorts[]``
on EPGs (see ``aci-redesign/data/nac-ndo/schema-aedce-ipv4.nac.yaml`` lines
52-58 for the inline note). So the EPG shells get created by Terraform but
the per-port bindings have to be PATCHed in afterwards via the REST API.

There was no FI-aware generator anywhere in the tree -- every existing
``deploy_bindings_python_v2*.py`` / ``generate_ipv6_bindings*.py`` was
written for legacy Design B (`VPC_D*A-B` / `protpaths-152-153`). This
script fills that gap for Design A.

Pipeline
--------

1.  ``generate_fi_bindings.py``  -> writes ``fi_bindings.json``
2.  Edit ``fi_bindings.json`` to set ``ndo_host`` and (if no vault)
    ``ndo_password``. If you maintain a per-EPG VLAN map for the FI side,
    drop it in via ``--vlan-map`` so the right encap lands on each EPG.
3.  ``./deploy_bindings.py fi_bindings.json --dry-run --no-vault``
4.  ``./deploy_bindings.py fi_bindings.json --no-vault``
5.  Click Deploy in the NDO UI.

CLI
---

::

    ./generate_fi_bindings.py \
        --schema-yaml ../data/nac-ndo/schema-aedce-ipv4.nac.yaml \
        --output      fi_bindings.json \
        --vlan-map    fi_vlan_map.json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Any


# -----------------------------------------------------------------------------
# Design A FI topology -- hardcoded with citations.
#
# Cross-reference any change here with:
#   aci-redesign/data/nac-aci-aedcg-prod/access-policies.nac.yaml
#   aci-redesign/data/nac-aci-aedck-prod/access-policies.nac.yaml
# -----------------------------------------------------------------------------
FI_TOPOLOGY: dict[str, dict[str, int]] = {
    "AEDCG": {"PC_FI_A": 152, "PC_FI_B": 153},
    "AEDCK": {"PC_FI_A": 119, "PC_FI_B": 191},
}

POD = "pod-1"

# DMZ EPGs are routed by AppProf-DMZ on the schema side. They still attach
# to the FIs the same way structurally, but flagging them here lets callers
# filter (``--include-dmz`` / ``--no-dmz``).
DEFAULT_DMZ_EPGS = {"EPG-D64-PROXY", "EPG-FWEB-PROXY", "EPG-RWEB-PROXY"}


# -----------------------------------------------------------------------------
# Schema YAML parsing -- regex-only, stdlib-only.
#
# This walks the schema YAML once, tracking the current AppProf and the
# current EPG block. Within each EPG block it watches for VMM-domain markers
# so callers can distinguish VMM-bound EPGs from physical-only EPGs (e.g.
# EPG-LB, EPG-LMR, EPG-VHOST-MGMT) without parsing YAML structure.
#
# We deliberately do NOT use PyYAML so this runs on a stock Python 3 install
# with no virtualenv. The structural assumption is "one EPG per
# `- name: EPG-*` line under an AppProf block, and VMM markers (either an
# inline `vmware_vmm_domains:` line or an anchor reference like
# `sites: *epg_sites_internal`) appear within the EPG block before the next
# EPG/AppProf line".
# -----------------------------------------------------------------------------

_APPPROF_RE = re.compile(r"^(\s*)-\s+name:\s+(AppProf-\S+)\s*$")
_EPG_RE = re.compile(r"^(\s*)-\s+name:\s+(EPG-\S+)\s*$")
# Inline VMM declaration: `                      vmware_vmm_domains:`
_VMM_INLINE_RE = re.compile(r"^\s*vmware_vmm_domains\s*:")
# YAML anchor reference for the canonical "VMM-bound sites" pattern, e.g.
# `sites: *epg_sites_internal`. We treat any anchor reference on `sites:`
# as VMM-bound because the schema convention uses anchors only for the
# VMM template; physical-only EPGs spell `sites:` out by hand.
_VMM_ANCHOR_REF_RE = re.compile(r"^\s*sites\s*:\s*\*\w")


def parse_epgs(schema_yaml_path: str) -> list[dict[str, Any]]:
    """
    Return [{"epg": "EPG-FOO", "app_profile": "AppProf-Bar", "has_vmm": bool},
    ...] for every EPG declared in the schema YAML.

    `has_vmm` is True when the EPG block contains either an inline
    ``vmware_vmm_domains:`` line or an anchor reference like
    ``sites: *epg_sites_internal`` (the schema-aedce-ipv4 convention for
    VMM-bound sites). False for the three physical EPGs (EPG-LB, EPG-LMR,
    EPG-VHOST-MGMT) whose ``sites:`` is spelled out without a VMM block.

    Works on the AEDCE-IPv4 schema layout (one template, two AppProfs). If
    you ever switch to a multi-template schema this will need a YAML parser
    instead.
    """
    with open(schema_yaml_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    current_appprof: str | None = None
    current_appprof_indent: int | None = None
    current_epg: str | None = None
    current_epg_appprof: str | None = None
    current_epg_has_vmm = False
    found: list[dict[str, Any]] = []

    def _close_current_epg() -> None:
        if current_epg is not None:
            found.append(
                {
                    "epg": current_epg,
                    "app_profile": current_epg_appprof,
                    "has_vmm": current_epg_has_vmm,
                }
            )

    for raw in lines:
        # Strip trailing newline; keep leading whitespace for indent tracking.
        line = raw.rstrip("\n")

        m = _APPPROF_RE.match(line)
        if m:
            _close_current_epg()
            current_epg = None
            current_epg_appprof = None
            current_epg_has_vmm = False
            current_appprof_indent = len(m.group(1))
            current_appprof = m.group(2)
            continue

        m = _EPG_RE.match(line)
        if m:
            indent = len(m.group(1))
            # Only count EPGs that live under the most recent AppProf
            # (i.e. indented deeper than its `- name: AppProf-...`).
            if (
                current_appprof is not None
                and current_appprof_indent is not None
                and indent > current_appprof_indent
            ):
                _close_current_epg()
                current_epg = m.group(2)
                current_epg_appprof = current_appprof
                current_epg_has_vmm = False
            continue

        if current_epg is not None and (
            _VMM_INLINE_RE.match(line) or _VMM_ANCHOR_REF_RE.match(line)
        ):
            current_epg_has_vmm = True

    _close_current_epg()
    return found


# -----------------------------------------------------------------------------
# VLAN map loading -- optional. If not provided, every binding gets vlan: null
# and the script warns. deploy_bindings.py rejects null VLANs at PATCH time
# (it requires an integer), but null is what we emit so the operator has a
# single "TODO" string to grep for in the output JSON.
# -----------------------------------------------------------------------------


def load_vlan_map(path: str | None) -> dict[str, int]:
    if path is None:
        return {}
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise SystemExit(f"vlan-map file {path!r} must be a JSON object")
    out: dict[str, int] = {}
    for k, v in data.items():
        if not isinstance(v, int):
            raise SystemExit(
                f"vlan-map entry for {k!r} must be an integer, got {type(v).__name__}"
            )
        out[k] = v
    return out


# -----------------------------------------------------------------------------
# Binding emission
# -----------------------------------------------------------------------------


def make_binding(
    site: str,
    epg: str,
    leaf: int,
    pc_name: str,
    vlan: int | None,
    deployment_immediacy: str,
    mode: str,
) -> dict[str, Any]:
    """
    One static-port binding for a single FI port-channel on a single site.

    NOTE on `path_type`: deploy_bindings.py auto-detects from the path text.
    Its rule (deploy_bindings.py lines 203-221) only flags a binding as
    `dpc` when the interface name starts with "Po"; it falls back to "port"
    otherwise. `PC_FI_A` does not start with "Po", so we set path_type
    explicitly. (deploy_bindings.py also has a small patch in this commit
    to recognize `PC_*` as dpc, but explicit beats implicit.)
    """
    return {
        "site": site,
        "epg_name": epg,
        "vlan": vlan,
        "path": f"topology/{POD}/paths-{leaf}/pathep-[{pc_name}]",
        "path_type": "dpc",
        "deployment_immediacy": deployment_immediacy,
        "mode": mode,
    }


def generate_bindings(
    epgs: list[dict[str, Any]],
    sites_filter: list[str],
    vlan_map: dict[str, int],
    deployment_immediacy: str,
    mode: str,
    skip_dmz: bool,
    dmz_epgs: set[str],
    physical_only: bool = False,
) -> tuple[list[dict[str, Any]], list[str], list[str]]:
    """
    Return (bindings, missing_vlans, skipped_vmm_epgs).

    When ``physical_only`` is True, EPGs whose schema entry has ``has_vmm``
    True are skipped. This implements Approach 1 in aci-redesign/README.md
    ("VLAN strategy -- read this before pushing"): for the lab cutover and
    for any production model that wants VMM dynamic VLAN learning to handle
    every VDS-backed EPG, only static-bind the physical-endpoint EPGs that
    cannot ride VMM (today: EPG-LB, EPG-LMR, EPG-VHOST-MGMT).
    """
    bindings: list[dict[str, Any]] = []
    missing_vlans: list[str] = []
    skipped_vmm: list[str] = []

    for entry in epgs:
        epg = entry["epg"]
        if skip_dmz and epg in dmz_epgs:
            continue
        if physical_only and entry.get("has_vmm"):
            skipped_vmm.append(epg)
            continue
        vlan = vlan_map.get(epg)
        if vlan is None:
            missing_vlans.append(epg)
        for site in sites_filter:
            for pc_name, leaf in FI_TOPOLOGY[site].items():
                bindings.append(
                    make_binding(
                        site=site,
                        epg=epg,
                        leaf=leaf,
                        pc_name=pc_name,
                        vlan=vlan,
                        deployment_immediacy=deployment_immediacy,
                        mode=mode,
                    )
                )

    return bindings, missing_vlans, skipped_vmm


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    default_schema = os.path.normpath(
        os.path.join(here, "..", "data", "nac-ndo", "schema-aedce-ipv4.nac.yaml")
    )

    p = argparse.ArgumentParser(
        description="Generate Design A UCS-FI static-port bindings JSON.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Output JSON is consumable by aci-redesign/scripts/deploy_bindings.py.\n"
            "Run deploy_bindings.py --dry-run first; then for real."
        ),
    )
    p.add_argument(
        "--schema-yaml",
        default=default_schema,
        help=f"NDO schema YAML to scan for EPG names (default: {default_schema})",
    )
    p.add_argument(
        "--output",
        "-o",
        default="fi_bindings.json",
        help="Output JSON path (default: fi_bindings.json)",
    )
    p.add_argument(
        "--site",
        choices=["AEDCG", "AEDCK", "both"],
        default="both",
        help="Restrict to one site (default: both -> 4 bindings/EPG)",
    )
    p.add_argument(
        "--vlan-map",
        help=(
            "Optional JSON file mapping EPG name -> integer VLAN. "
            "EPGs missing from the map get vlan: null in the output, "
            "which deploy_bindings.py will refuse to PATCH until you "
            "fill it in."
        ),
    )
    p.add_argument(
        "--ndo-host",
        default="REPLACE_ME",
        help="NDO host -- written into the output JSON header (default: REPLACE_ME)",
    )
    p.add_argument(
        "--ndo-username",
        default="admin",
        help="NDO username (default: admin)",
    )
    p.add_argument(
        "--schema-name",
        default="AEDCE-IPv4",
        help="Schema name written into the output JSON (default: AEDCE-IPv4)",
    )
    p.add_argument(
        "--deployment-immediacy",
        choices=["immediate", "lazy"],
        default="immediate",
    )
    p.add_argument(
        "--mode",
        choices=["regular", "native", "untagged"],
        default="regular",
    )
    p.add_argument(
        "--skip-dmz",
        action="store_true",
        help=(
            "Skip the three DMZ EPGs (EPG-D64-PROXY, EPG-FWEB-PROXY, "
            "EPG-RWEB-PROXY). Useful if those terminate behind a firewall, "
            "not the FIs."
        ),
    )
    p.add_argument(
        "--physical-only",
        action="store_true",
        help=(
            "Only emit bindings for EPGs that DO NOT have a VMware VMM "
            "domain in the schema. For schema-aedce-ipv4.nac.yaml today "
            "that's EPG-LB, EPG-LMR, EPG-VHOST-MGMT (F5 / LMR gateways / "
            "ESXi vmkernel -- physical endpoints that cannot ride a VDS "
            "port-group). Implements Approach 1 in aci-redesign/README.md "
            "'VLAN strategy -- read this before pushing': use this for "
            "the lab cutover, where VMM dynamic VLAN learning handles "
            "every VDS-backed EPG and only the physical EPGs need static "
            "binds. For prod, omit this flag (Approach 2: VMM + static "
            "together on the FI uplinks)."
        ),
    )
    p.add_argument(
        "--output-manifest",
        help=(
            "Write a sanitized manifest (no creds, no VLANs, just EPG "
            "names + mode) alongside the main bindings file. CI consumes "
            "this via check_fi_bindings_parity.py to detect schema/binding "
            "drift -- adding an EPG to the schema without regenerating "
            "the manifest fails the parity check and blocks the merge. "
            "Recommended path: scripts/fi_epg_manifest.json"
        ),
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print summary and a 5-binding sample to stdout, do not write the output file.",
    )

    args = p.parse_args()

    if not os.path.isfile(args.schema_yaml):
        print(f"error: schema YAML not found: {args.schema_yaml}", file=sys.stderr)
        return 2

    epgs = parse_epgs(args.schema_yaml)
    if not epgs:
        print(
            f"error: no EPGs found in {args.schema_yaml}. "
            f"Schema YAML may have a layout this regex parser can't handle.",
            file=sys.stderr,
        )
        return 2

    sites_filter = ["AEDCG", "AEDCK"] if args.site == "both" else [args.site]
    vlan_map = load_vlan_map(args.vlan_map)

    bindings, missing_vlans, skipped_vmm = generate_bindings(
        epgs=epgs,
        sites_filter=sites_filter,
        vlan_map=vlan_map,
        deployment_immediacy=args.deployment_immediacy,
        mode=args.mode,
        skip_dmz=args.skip_dmz,
        dmz_epgs=DEFAULT_DMZ_EPGS,
        physical_only=args.physical_only,
    )

    output_doc: dict[str, Any] = {
        "_comment_top": (
            "Generated by generate_fi_bindings.py. Edit ndo_host before "
            "deploying. Replace any null vlans with the FI VLAN for that "
            "EPG, or pass --vlan-map at generate time."
        ),
        "ndo_host": args.ndo_host,
        "ndo_username": args.ndo_username,
        "ndo_password": "<used only with --no-vault>",
        "schema_name": args.schema_name,
        "static_port_bindings": bindings,
    }

    # ---------- Summary ----------
    mode_label = "physical-only (Approach 1)" if args.physical_only else "full (Approach 2)"
    print(f"Schema YAML:        {args.schema_yaml}")
    print(f"Schema name:        {args.schema_name}")
    print(f"Mode:               {mode_label}")
    print(f"EPGs found:         {len(epgs)}")
    vmm_count = sum(1 for e in epgs if e.get("has_vmm"))
    print(f"  VMM-bound:        {vmm_count}")
    print(f"  Physical-only:    {len(epgs) - vmm_count}")
    if args.skip_dmz:
        skipped = [e for e in epgs if e["epg"] in DEFAULT_DMZ_EPGS]
        print(f"DMZ EPGs skipped:   {len(skipped)} ({', '.join(e['epg'] for e in skipped) or '-'})")
    if args.physical_only:
        print(f"VMM EPGs skipped:   {len(skipped_vmm)}")
    print(f"Sites:              {', '.join(sites_filter)}")
    print(f"VLAN map entries:   {len(vlan_map)}")
    print(f"Bindings generated: {len(bindings)}")
    if missing_vlans:
        print(
            f"WARNING: {len(missing_vlans)} EPG(s) have no VLAN in the map "
            f"and will emit vlan: null. First few: "
            f"{', '.join(missing_vlans[:5])}"
        )

    if args.dry_run:
        print("\n--- DRY-RUN SAMPLE (first 5 bindings) ---")
        sample = bindings[:5]
        print(json.dumps(sample, indent=2))
        print("\nDry run: not writing output file.")
        return 0

    # Write atomically: write to tmp, then rename.
    tmp = args.output + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(output_doc, f, indent=2)
        f.write("\n")
    os.replace(tmp, args.output)
    # Restrict mode to 0600 to avoid leaking the placeholder password line.
    try:
        os.chmod(args.output, 0o600)
    except OSError:
        # Best-effort on filesystems that do not honor chmod.
        pass

    print(f"\nWrote {args.output} ({len(bindings)} bindings).")

    # ---------- Optional sanitized manifest for CI parity check ----------
    if args.output_manifest:
        # The manifest is the set of EPGs whose bindings we just emitted.
        # CI compares this set to the schema (filtered by mode) to catch
        # the "EPG added to schema but never re-pushed" failure mode.
        manifest_epgs = sorted({b["epg_name"] for b in bindings})
        manifest_doc = {
            "_comment_top": (
                "Tracked manifest of EPGs covered by the most recent "
                "generate_fi_bindings.py run. Committed to git and verified "
                "by .gitlab-ci.yml via check_fi_bindings_parity.py to detect "
                "schema/binding drift. DO NOT hand-edit -- regenerate via "
                "`./generate_fi_bindings.py --output-manifest fi_epg_manifest.json`."
            ),
            "schema_yaml": os.path.relpath(
                os.path.abspath(args.schema_yaml),
                start=os.path.dirname(os.path.abspath(args.output_manifest)),
            ),
            "mode": "physical-only" if args.physical_only else "full",
            "skip_dmz": bool(args.skip_dmz),
            "epgs": manifest_epgs,
        }
        manifest_tmp = args.output_manifest + ".tmp"
        with open(manifest_tmp, "w", encoding="utf-8") as f:
            json.dump(manifest_doc, f, indent=2)
            f.write("\n")
        os.replace(manifest_tmp, args.output_manifest)
        print(f"Wrote {args.output_manifest} ({len(manifest_epgs)} EPGs, mode={manifest_doc['mode']}).")

    print("Next: ./deploy_bindings.py {} --dry-run --no-vault".format(args.output))
    return 0


if __name__ == "__main__":
    sys.exit(main())

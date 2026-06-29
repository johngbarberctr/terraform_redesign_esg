#!/usr/bin/env python3
"""
check_fi_bindings_parity.py -- detect schema / FI-binding drift in CI.
================================================================================

Why this exists
---------------

The V2 redesign deploys two coupled artifacts:

    1. Tenant tree (VRFs, BDs, EPGs, contracts) -- pushed via Terraform
       from ``aci-ndo/data/nac-ndo/schema-africom-v2.nac.yaml``.

    2. FI-uplink static-port bindings on PC_FI_A / PC_FI_B (Approach 2 in
       README_LAB.md "VLAN strategy") -- PATCHed into NDO via
       ``deploy_bindings.py`` from a JSON file produced by
       ``generate_fi_bindings.py``.

The schema is the source of truth for which EPGs exist; the bindings JSON
is the source of truth for which EPGs are actually wired to the FIs. If
those two drift -- e.g. an operator adds an EPG to the schema, runs
``terraform apply`` against the NDO root, but forgets to regenerate and
push the FI bindings -- the EPG comes up on NDO with no path to the FI
uplinks, and any VM behind a UCS FI on that EPG silently loses L2.

This script enforces parity in CI by comparing the schema EPG set to the
EPG set recorded in a sanitized manifest committed alongside the schema.
The manifest is produced by ``generate_fi_bindings.py --output-manifest``
and contains no creds, no VLANs -- just the EPG list, the mode (full vs
physical-only), and which schema YAML it was generated from.

Modes
-----

The manifest's ``mode`` field selects the parity rule:

    * ``"full"`` (Approach 2, prod): every EPG declared in the schema
      must appear in the manifest. Manifest entries that don't match a
      schema EPG fail the check.

    * ``"physical-only"`` (Approach 1, lab): only EPGs that lack a VMM
      domain in the schema (today: EPG-LB-V2, EPG-LMR-V2, EPG-VHOST-MGMT-V2)
      must appear. VMM-bound EPGs are intentionally skipped because lab
      cutover relies on VMM dynamic VLAN learning. Manifest entries for
      VMM-bound EPGs in this mode are reported as warnings.

CLI
---

::

    ./check_fi_bindings_parity.py \\
        --schema-yaml ../data/nac-ndo/schema-africom-v2.nac.yaml \\
        --manifest    fi_epg_manifest.json

Exit codes:

    0 -- parity (schema and manifest agree)
    1 -- drift detected (added/removed/typo'd EPG)
    2 -- structural error (missing file, malformed JSON, etc.)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

# Reuse the schema parser from the generator. Both scripts live in the
# same directory; running from anywhere else requires PYTHONPATH or an
# explicit chdir, which the gitlab-ci job does (`cd scripts`).
import generate_fi_bindings as gen


VALID_MODES = ("full", "physical-only")


class ManifestError(Exception):
    """Raised by load_manifest on a structural problem with the manifest.

    The CLI catches this in main() and exits with code 2 (structural error)
    rather than 1 (which is reserved for genuine drift). Tests can catch
    this without going through SystemExit semantics.
    """


def load_manifest(path: str) -> dict[str, Any]:
    if not os.path.isfile(path):
        raise ManifestError(f"manifest not found: {path}")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        raise ManifestError(f"manifest {path} is not valid JSON: {e}") from e
    if not isinstance(data, dict):
        raise ManifestError(f"manifest {path} top-level must be a JSON object")
    mode = data.get("mode")
    if mode not in VALID_MODES:
        raise ManifestError(
            f"manifest {path} has mode={mode!r}; expected one of {VALID_MODES}"
        )
    epgs = data.get("epgs")
    if not isinstance(epgs, list) or not all(isinstance(x, str) for x in epgs):
        raise ManifestError(f"manifest {path} 'epgs' must be a list of strings")
    return data


def expected_epgs_from_schema(
    schema_epgs: list[dict[str, Any]],
    mode: str,
    skip_dmz: bool,
    dmz_epgs: set[str],
) -> set[str]:
    """Return the set of EPG names that must appear in the manifest."""
    out: set[str] = set()
    for entry in schema_epgs:
        epg = entry["epg"]
        if skip_dmz and epg in dmz_epgs:
            continue
        if mode == "physical-only" and entry.get("has_vmm"):
            continue
        out.add(epg)
    return out


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    default_schema = os.path.normpath(
        os.path.join(here, "..", "aci-ndo", "data", "nac-ndo", "schema-africom-v2.nac.yaml")
    )
    default_manifest = os.path.join(here, "fi_epg_manifest.json")

    p = argparse.ArgumentParser(
        description=(
            "Verify scripts/fi_epg_manifest.json matches "
            "aci-ndo/data/nac-ndo/schema-africom-v2.nac.yaml. "
            "Run from CI to fail fast on schema/binding drift."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Exit codes: 0=parity, 1=drift, 2=structural error.\n"
            "Regenerate manifest after schema edits via:\n"
            "  ./generate_fi_bindings.py --output fi_bindings.json "
            "--output-manifest fi_epg_manifest.json"
        ),
    )
    p.add_argument("--schema-yaml", default=default_schema)
    p.add_argument("--manifest", default=default_manifest)
    args = p.parse_args()

    if not os.path.isfile(args.schema_yaml):
        print(f"error: schema YAML not found: {args.schema_yaml}", file=sys.stderr)
        return 2

    try:
        manifest = load_manifest(args.manifest)
    except ManifestError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    mode = manifest["mode"]
    skip_dmz = bool(manifest.get("skip_dmz", False))
    manifest_epgs = set(manifest["epgs"])

    schema_epgs = gen.parse_epgs(args.schema_yaml)
    if not schema_epgs:
        print(
            f"error: no EPGs found in {args.schema_yaml}; the manifest "
            f"would always disagree. Check the schema YAML layout.",
            file=sys.stderr,
        )
        return 2

    expected = expected_epgs_from_schema(
        schema_epgs=schema_epgs,
        mode=mode,
        skip_dmz=skip_dmz,
        dmz_epgs=gen.DEFAULT_DMZ_EPGS,
    )
    schema_epg_names = {e["epg"] for e in schema_epgs}
    vmm_epg_names = {e["epg"] for e in schema_epgs if e.get("has_vmm")}

    missing_in_manifest = expected - manifest_epgs
    extra_in_manifest = manifest_epgs - expected
    unknown_in_manifest = manifest_epgs - schema_epg_names

    print(f"Schema YAML:          {args.schema_yaml}")
    print(f"Manifest:             {args.manifest}")
    print(f"Manifest mode:        {mode}")
    print(f"Manifest skip_dmz:    {skip_dmz}")
    print(f"Schema EPGs total:    {len(schema_epgs)}")
    print(f"  VMM-bound:          {len(vmm_epg_names)}")
    print(f"  Physical-only:      {len(schema_epg_names) - len(vmm_epg_names)}")
    print(f"Manifest EPGs:        {len(manifest_epgs)}")
    print(f"Expected (per mode):  {len(expected)}")

    rc = 0

    if missing_in_manifest:
        rc = 1
        print(
            "\nDRIFT: schema declares EPGs that are MISSING from the manifest.\n"
            "These EPGs exist in the tenant tree but no FI binding has been "
            "recorded for them. Likely cause: someone added an EPG to "
            f"{os.path.basename(args.schema_yaml)} without re-running "
            "generate_fi_bindings.py --output-manifest.",
            file=sys.stderr,
        )
        for epg in sorted(missing_in_manifest):
            print(f"  - {epg}", file=sys.stderr)

    # In physical-only mode, the manifest is allowed to omit VMM-bound EPGs;
    # any non-VMM EPG showing up under "extra" is genuine drift.
    if mode == "physical-only":
        unexpected_vmm_in_manifest = manifest_epgs & vmm_epg_names
        legit_extras = extra_in_manifest - unexpected_vmm_in_manifest
        if unexpected_vmm_in_manifest:
            print(
                "\nWARNING: manifest is in physical-only mode but lists "
                "VMM-bound EPGs. These will be statically bound on top of "
                "their VMM domain; this is fine for prod (Approach 2) but "
                "if you intended Approach 1, regenerate without these.",
                file=sys.stderr,
            )
            for epg in sorted(unexpected_vmm_in_manifest):
                print(f"  ? {epg} (has VMM)", file=sys.stderr)
    else:
        legit_extras = extra_in_manifest

    if legit_extras:
        rc = 1
        print(
            "\nDRIFT: manifest lists EPGs that are NOT in the schema (or "
            "not expected for the current mode).",
            file=sys.stderr,
        )
        for epg in sorted(legit_extras):
            tag = " (unknown to schema)" if epg in unknown_in_manifest else ""
            print(f"  + {epg}{tag}", file=sys.stderr)

    if rc == 0:
        print("\nOK: schema and manifest are in parity.")
    else:
        print(
            "\nFix:  ./generate_fi_bindings.py "
            "--output fi_bindings.json --output-manifest fi_epg_manifest.json"
            + (" --physical-only" if mode == "physical-only" else "")
            + ("  --skip-dmz" if skip_dmz else ""),
            file=sys.stderr,
        )

    return rc


if __name__ == "__main__":
    sys.exit(main())

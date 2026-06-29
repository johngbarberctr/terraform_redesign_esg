#!/usr/bin/env python3
"""
NDO static-port-binding dumper for the V2 tenant redesign.

Reads an existing NDO schema (default: AFRICOM -- the IPv6 RCC redesign in
AppProf-RCC) and emits its per-EPG staticPorts[] in the JSON shape that
scripts/deploy_bindings.py consumes. Designed so the operator does not
hand-author hundreds of port lines: dump from the live source-of-truth,
review/edit, push.

Why this exists:
  * The V2 redesign (schema AFRICOM-V2 / AppProf-NetCentric-V2 + AppProf-DMZ-V2)
    has the SAME 39 EPG functions as the IPv6 redesign in AFRICOM / AppProf-RCC,
    just suffixed -V2 on the target side (see docs/DESIGN.md
    "Naming convention" for why).
  * Dual-stack hosts land on the same physical interfaces, so the IPv6
    binding paths (leaf, port, vPC) are reusable for V2.
  * The VLANs are NOT reusable: IPv6 uses static 3001-3500, V2 uses VMM
    dynamic 3501-3967. The dumper strips VLAN by default and the operator
    decides downstream how to fill it in (or whether to push static ports
    at all on VMM-only EPGs).

Auth:
  * Same multi-attempt flow as deploy_bindings.py (Nexus Dashboard /login
    with domain=local then DefaultAuth, then NDO 3.x /api/v1/auth/login).
  * Reads NDO_HOST / NDO_USER / NDO_PASSWORD from env, or accepts
    --host / --username and prompts for password (no echo).

Output:
  JSON file matching scripts/bindings.example.json. Each binding becomes:
    {
      "site":     "Site1" | "Site2",
      "epg_name": "EPG-...",
      "path":     "topology/pod-1/(prot)?paths-N(-M)?/pathep-[...]",
      "deployment_immediacy": "immediate" | "lazy",
      "mode":     "regular" | "untagged" | "native",
      "port_type": "port" | "vpc" | "dpc"
      # NOTE: "vlan" intentionally omitted under --strip-vlan (the default)
    }

Filters (default: lab-safe):
  --exclude-leaves 101,102   border leaves (L2 collection only in IPv6)
  --leaves "..."             include-only filter, comma-separated leaf IDs
                             (e.g. 152,153,119,191 for the Site1+Site2 lab)

ANP routing:
  --target-netcentric-anp AppProf-NetCentric-V2
  --target-dmz-anp        AppProf-DMZ-V2
  --dmz-epgs "EPG-D64-PROXY-V2,EPG-FWEB-PROXY-V2,EPG-RWEB-PROXY-V2"
  Everything not in --dmz-epgs lands under the netcentric ANP.

  Note: a third ANP, AppProf-AppCentric-V2, exists in tenant AFR-DEL.Services but is
  managed APIC-direct (../data/nac-aci-shared/tenant-eur-esgs.nac.yaml)
  and only holds the two Phase-2 ESGs. It contains NO EPGs, so it is
  never a binding target -- bindings always go to the NDO-managed
  AppProf-NetCentric-V2 or AppProf-DMZ-V2 ANPs above.

Validation:
  If --target-schema is set (default AFRICOM-V2), the script also pulls
  that schema and warns about: source EPGs missing in the target, target
  EPGs with zero source bindings, and per-site/per-leaf coverage gaps.

Note: source EPG names from AFRICOM/AppProf-RCC do NOT carry the -V2 suffix
(they are legacy names). The dumper does not auto-rewrite EPG names; the
operator must either pre-edit the bindings JSON to rename source EPGs to
their -V2 equivalents (e.g. EPG-WEB-SVR -> EPG-WEB-SVR-V2) before pushing
with deploy_bindings.py, or use --target-schema parity warnings to spot
the mismatches and fix them in bulk.

Example:
  export NDO_HOST=10.51.32.30 NDO_USER=admin
  ./dump_bindings.py --output current_bindings.json
  # review current_bindings.json, then:
  ./deploy_bindings.py current_bindings.json --no-vault --dry-run
"""
import argparse
import getpass
import json
import os
import re
import sys
from collections import defaultdict

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

DEFAULT_SOURCE_SCHEMA = "AFRICOM"
DEFAULT_SOURCE_ANP    = "AppProf-RCC"
DEFAULT_TARGET_SCHEMA = "AFRICOM-V2"
DEFAULT_NETCENTRIC    = "AppProf-NetCentric-V2"
DEFAULT_DMZ_ANP       = "AppProf-DMZ-V2"
DEFAULT_DMZ_EPGS      = "EPG-D64-PROXY-V2,EPG-FWEB-PROXY-V2,EPG-RWEB-PROXY-V2"
DEFAULT_EXCLUDE_LEAFS = "101,102"


def authenticate(host, username, password):
    """Authenticate against ND/NDO. Returns a configured requests.Session."""
    s = requests.Session()
    s.verify = False
    base = f"https://{host}"

    # Attempt 1: ND 4.x /login (domain=local then DefaultAuth)
    for domain in ("local", "DefaultAuth"):
        try:
            r = s.post(f"{base}/login",
                       json={"userName": username,
                             "userPasswd": password,
                             "domain": domain},
                       timeout=30)
        except requests.exceptions.ConnectionError:
            break
        except Exception as e:
            print(f"  ND /login attempt error: {e}", file=sys.stderr)
            continue
        if r.status_code == 200:
            j = r.json()
            tok = j.get("token") or j.get("jwttoken")
            if tok:
                s.headers["Authorization"] = f"Bearer {tok}"
                print(f"Authenticated via ND /login (domain={domain}).")
                return s
            if s.cookies:
                print(f"Authenticated via ND /login cookies (domain={domain}).")
                return s

    # Attempt 2: NDO 3.x /api/v1/auth/login (with and without domain)
    for body in ({"username": username, "password": password, "domain": "local"},
                 {"username": username, "password": password}):
        try:
            r = s.post(f"{base}/api/v1/auth/login", json=body, timeout=30)
        except Exception as e:
            print(f"  /api/v1/auth/login attempt error: {e}", file=sys.stderr)
            continue
        if r.status_code == 200:
            tok = r.json().get("token")
            if tok:
                s.headers["Authorization"] = f"Bearer {tok}"
                print("Authenticated via /api/v1/auth/login.")
                return s

    print("ERROR: all NDO authentication attempts failed.", file=sys.stderr)
    sys.exit(2)


def get_sites_map(session, host):
    """Return {site_id: site_name}."""
    r = session.get(f"https://{host}/api/v1/sites", timeout=30)
    r.raise_for_status()
    return {site["id"]: site["name"] for site in r.json().get("sites", [])}


def get_schema(session, host, schema_name):
    """Fetch a full schema by display name. Returns the schema dict or None."""
    r = session.get(f"https://{host}/api/v1/schemas", timeout=60)
    r.raise_for_status()
    schemas = r.json().get("schemas", [])
    for s in schemas:
        if s.get("displayName") == schema_name:
            full = session.get(f"https://{host}/api/v1/schemas/{s['id']}",
                               timeout=60)
            full.raise_for_status()
            return full.json()
    return None


def parse_leaf_from_path(path):
    """Return the (single) leaf ID for a regular path or 'A-B' for a vPC."""
    m = re.match(r"topology/pod-\d+/paths-(\d+)/pathep-\[", path)
    if m:
        return m.group(1)
    m = re.match(r"topology/pod-\d+/protpaths-(\d+-\d+)/pathep-\[", path)
    if m:
        return m.group(1)
    return None


def leaf_in_filter(leaf_id, allow_set, deny_set):
    """leaf_id may be 'N' (regular) or 'A-B' (vPC). Returns True if any of the
    member leaves passes the filter (allow if set, else deny)."""
    if leaf_id is None:
        return False
    members = leaf_id.split("-")
    if allow_set:
        return any(m in allow_set for m in members)
    return not any(m in deny_set for m in members)


def detect_port_type(path):
    if "protpaths-" in path:
        return "vpc"
    m = re.search(r"pathep-\[([^\]]+)\]", path)
    if m and m.group(1).startswith("Po"):
        return "dpc"
    return "port"


def build_target_epg_set(target_schema):
    """Set of EPG names that exist in the target schema (any ANP, any template)."""
    epgs = set()
    if not target_schema:
        return epgs
    for tpl in target_schema.get("templates", []):
        for anp in tpl.get("anps", []):
            for epg in anp.get("epgs", []):
                epgs.add(epg.get("name"))
    return epgs


def dump_source(session, host, source_schema, source_anp, sites_map,
                allow_leafs, deny_leafs, dmz_epgs, target_netcentric,
                target_dmz, strip_vlan):
    """Walk the source schema and produce a list of binding dicts."""
    bindings = []
    site_blocks = source_schema.get("sites", [])
    if not site_blocks:
        print("WARNING: source schema has no site blocks.", file=sys.stderr)
        return bindings

    stats = {
        "ports_seen":       0,
        "skipped_leaf":     0,
        "skipped_no_path":  0,
        "kept":             0,
    }
    epg_seen_per_site = defaultdict(set)

    for site_block in site_blocks:
        site_name = sites_map.get(site_block.get("siteId"), "<unknown>")
        for anp in site_block.get("anps", []):
            anp_ref = anp.get("anpRef", "")
            anp_name = anp_ref.rsplit("/", 1)[-1] if anp_ref else ""
            if anp_name != source_anp:
                continue

            for epg in anp.get("epgs", []):
                epg_ref = epg.get("epgRef", "")
                epg_name = epg_ref.rsplit("/", 1)[-1] if epg_ref else ""
                if not epg_name:
                    continue
                target_anp = (target_dmz if epg_name in dmz_epgs
                              else target_netcentric)
                epg_seen_per_site[site_name].add(epg_name)

                for sp in epg.get("staticPorts", []):
                    stats["ports_seen"] += 1
                    path = sp.get("path", "")
                    leaf_id = parse_leaf_from_path(path)
                    if leaf_id is None:
                        stats["skipped_no_path"] += 1
                        continue
                    if not leaf_in_filter(leaf_id, allow_leafs, deny_leafs):
                        stats["skipped_leaf"] += 1
                        continue

                    binding = {
                        "site":      site_name,
                        "epg_name":  epg_name,
                        "anp_name":  target_anp,
                        "path":      path,
                        "port_type": detect_port_type(path),
                        "deployment_immediacy":
                            sp.get("deploymentImmediacy", "immediate"),
                        "mode": sp.get("mode", "regular"),
                    }
                    if not strip_vlan:
                        binding["vlan"] = sp.get("portEncapVlan")
                    bindings.append(binding)
                    stats["kept"] += 1
    return bindings, stats, epg_seen_per_site


def summarize(bindings, stats, epg_seen_per_site, source_anp,
              target_epgs, dmz_epgs):
    print("\n" + "=" * 60)
    print(f"DUMP SUMMARY  (source ANP: {source_anp})")
    print("=" * 60)
    print(f"Static ports seen in source ANP:     {stats['ports_seen']}")
    print(f"Skipped (no parseable path):         {stats['skipped_no_path']}")
    print(f"Skipped (leaf filter):               {stats['skipped_leaf']}")
    print(f"Kept:                                {stats['kept']}")

    by_type = defaultdict(int)
    by_site = defaultdict(int)
    by_site_type = defaultdict(lambda: defaultdict(int))
    by_epg = defaultdict(int)
    for b in bindings:
        by_type[b["port_type"]] += 1
        by_site[b["site"]] += 1
        by_site_type[b["site"]][b["port_type"]] += 1
        by_epg[b["epg_name"]] += 1

    print(f"\nBy port type:")
    for t, n in sorted(by_type.items()):
        print(f"  {t:5s}: {n}")
    print(f"\nBy site:")
    for site, total in sorted(by_site.items()):
        print(f"  {site}: {total}")
        for t, n in sorted(by_site_type[site].items()):
            print(f"    {t:5s}: {n}")

    if target_epgs:
        source_epgs = set(by_epg.keys())
        missing_in_target = sorted(source_epgs - target_epgs)
        empty_in_source   = sorted(target_epgs - source_epgs)
        print(f"\nSource EPGs not in target schema: {len(missing_in_target)}")
        for e in missing_in_target:
            print(f"  -- {e} (will be DROPPED if you push as-is)")
        print(f"Target EPGs with no source bindings: {len(empty_in_source)}")
        for e in empty_in_source:
            print(f"  ?? {e}")

    print(f"\nDMZ vs NetCentric routing:")
    dmz_count = sum(1 for b in bindings if b["epg_name"] in dmz_epgs)
    nc_count  = len(bindings) - dmz_count
    print(f"  AppProf-DMZ:         {dmz_count}")
    print(f"  AppProf-NetCentric:  {nc_count}")
    print("=" * 60 + "\n")


def main():
    p = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=__doc__,
    )
    p.add_argument("--host",             default=os.environ.get("NDO_HOST", ""),
                   help="NDO IP or hostname (default: $NDO_HOST)")
    p.add_argument("--username",         default=os.environ.get("NDO_USER", "admin"),
                   help="NDO username (default: $NDO_USER or admin)")
    p.add_argument("--password",         default=os.environ.get("NDO_PASSWORD"),
                   help="NDO password (default: $NDO_PASSWORD; prompts otherwise)")
    p.add_argument("--source-schema",    default=DEFAULT_SOURCE_SCHEMA)
    p.add_argument("--source-anp",       default=DEFAULT_SOURCE_ANP)
    p.add_argument("--target-schema",    default=DEFAULT_TARGET_SCHEMA,
                   help="Validate dump against this schema (set '' to skip)")
    p.add_argument("--target-netcentric-anp", default=DEFAULT_NETCENTRIC)
    p.add_argument("--target-dmz-anp",        default=DEFAULT_DMZ_ANP)
    p.add_argument("--dmz-epgs",         default=DEFAULT_DMZ_EPGS,
                   help="Comma-separated EPG names that route to the DMZ ANP")
    p.add_argument("--exclude-leaves",   default=DEFAULT_EXCLUDE_LEAFS,
                   help="Comma-separated leaf IDs to skip "
                        "(default: 101,102 border leaves)")
    p.add_argument("--leaves",           default="",
                   help="Comma-separated leaf IDs to INCLUDE only "
                        "(overrides --exclude-leaves; e.g. 152,153,119,191)")
    p.add_argument("--strip-vlan",       action="store_true", default=True,
                   help="Omit VLAN encap from output (default; safe for VMM)")
    p.add_argument("--keep-vlan",        dest="strip_vlan", action="store_false",
                   help="Keep the source VLAN in the output (will be rejected "
                        "by APIC if it's outside the target VMM pool)")
    p.add_argument("--output",           default="current_bindings.json")
    p.add_argument("--dry-run",          action="store_true",
                   help="Print summary; do not write the output file")
    p.add_argument("--target-schema-name-in-output",
                   default=None,
                   help="schema_name field value in the output JSON "
                        "(default = --target-schema)")
    args = p.parse_args()

    if not args.host:
        print("ERROR: --host or NDO_HOST is required.", file=sys.stderr)
        sys.exit(1)
    password = args.password
    if not password:
        password = getpass.getpass(f"NDO password for {args.username}@{args.host}: ")

    session = authenticate(args.host, args.username, password)

    print(f"Fetching site map ...")
    sites_map = get_sites_map(session, args.host)

    print(f"Fetching source schema {args.source_schema!r} ...")
    source = get_schema(session, args.host, args.source_schema)
    if not source:
        print(f"ERROR: schema {args.source_schema!r} not found in NDO.",
              file=sys.stderr)
        sys.exit(1)

    target_schema = None
    target_epgs = set()
    if args.target_schema:
        print(f"Fetching target schema {args.target_schema!r} for validation ...")
        target_schema = get_schema(session, args.host, args.target_schema)
        if not target_schema:
            print(f"WARNING: target schema {args.target_schema!r} not found; "
                  "validation will be skipped.", file=sys.stderr)
        else:
            target_epgs = build_target_epg_set(target_schema)

    allow_leafs = set(x.strip() for x in args.leaves.split(",") if x.strip())
    deny_leafs  = set(x.strip() for x in args.exclude_leaves.split(",") if x.strip())
    dmz_epgs    = set(x.strip() for x in args.dmz_epgs.split(",") if x.strip())

    bindings, stats, epg_seen = dump_source(
        session, args.host, source,
        source_anp=args.source_anp,
        sites_map=sites_map,
        allow_leafs=allow_leafs,
        deny_leafs=deny_leafs,
        dmz_epgs=dmz_epgs,
        target_netcentric=args.target_netcentric_anp,
        target_dmz=args.target_dmz_anp,
        strip_vlan=args.strip_vlan,
    )

    summarize(bindings, stats, epg_seen, args.source_anp,
              target_epgs, dmz_epgs)

    if args.dry_run:
        print("(dry run -- not writing output file)")
        if bindings:
            print("First 5 bindings:")
            for b in bindings[:5]:
                print("  " + json.dumps(b))
        return

    out = {
        "_comment_top": (
            f"Generated by dump_bindings.py from {args.host}, "
            f"source schema {args.source_schema!r} / ANP {args.source_anp!r}. "
            f"Strip VLAN: {args.strip_vlan}. "
            "Review before piping into deploy_bindings.py."
        ),
        "ndo_host":     args.host,
        "ndo_username": args.username,
        "schema_name":  args.target_schema_name_in_output or args.target_schema,
        "static_port_bindings": bindings,
    }
    with open(args.output, "w") as f:
        json.dump(out, f, indent=2)
    os.chmod(args.output, 0o600)
    print(f"Wrote {len(bindings)} bindings to {args.output} (mode 0600).")


if __name__ == "__main__":
    main()

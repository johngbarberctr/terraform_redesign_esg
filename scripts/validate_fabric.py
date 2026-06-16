#!/usr/bin/env python3
"""
AFRICOM NIPR — Fabric Health Validation & Phase 0 Automation
=============================================================
Covers all automatable steps from AFRICOM_Implementation_Plan.md Phase 0,
and is used as the pre/post gate for every subsequent phase.

WHAT IT DOES
  Health checks (every run):
    0.3  Fabric health baseline — cluster, faults, object counts, BGP, VMM
    0.5  VMM domain controller status
    0.4  BGP prefix counts (per VRF, per site)

  Phase 0 snapshot/backup actions (opt-in via --phase0 or individual flags):
    0.1  Trigger APIC configuration snapshot on Kelley and Del Din
    0.2  Trigger NDO configuration backup
    0.6  Export AFRICOM NIPR schema JSON to artifacts dir

  Drift detection (opt-in via --compare <previous-baseline.json>):
    Compares counts and settings across all tracked checks.

EXIT CODES
  0  All critical checks passed (warnings may be present).
  1  One or more critical checks failed.
  2  Configuration / auth error (cannot reach a fabric).

AUTH — environment variables (same as dump_bindings.py):
  KELLEY_APIC_URL  KELLEY_APIC_USERNAME  KELLEY_APIC_PASSWORD
  DELDIN_APIC_URL  DELDIN_APIC_USERNAME  DELDIN_APIC_PASSWORD
  NDO_URL          NDO_USERNAME          NDO_PASSWORD

USAGE
  # Full Phase 0 (snapshots + backup + export + health baseline):
  python3 scripts/validate_fabric.py --phase0 \\
    --artifacts-dir scripts/baseline/pre-phase1

  # Health-only baseline before a change (fast):
  python3 scripts/validate_fabric.py -o scripts/baseline/pre-phase1.json

  # Post-change verify with drift report:
  python3 scripts/validate_fabric.py \\
    --compare scripts/baseline/pre-phase1.json \\
    -o scripts/baseline/post-phase1.json

  # Skip NDO entirely (unreachable):
  python3 scripts/validate_fabric.py --skip-ndo
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
import time
import urllib.request
import urllib.error
import urllib.parse
import ssl
import getpass
from typing import Any

# ─────────────────────────────────────────────────────────────────────────────
# ANSI colours — auto-disabled when stdout is not a TTY
# ─────────────────────────────────────────────────────────────────────────────
_TTY = sys.stdout.isatty()

def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _TTY else text

PASS = lambda t: _c("32;1", t)
WARN = lambda t: _c("33;1", t)
FAIL = lambda t: _c("31;1", t)
INFO = lambda t: _c("36",   t)
BOLD = lambda t: _c("1",    t)

STATUS_ICON  = {"pass": PASS("✔"), "warn": WARN("⚠"), "fail": FAIL("✘")}
STATUS_LABEL = {"pass": PASS("PASS"), "warn": WARN("WARN"), "fail": FAIL("FAIL")}

# ─────────────────────────────────────────────────────────────────────────────
# HTTP helpers — stdlib only, no external dependencies
# ─────────────────────────────────────────────────────────────────────────────

def _ssl_ctx(verify: bool = False) -> ssl.SSLContext:
    ctx = ssl.create_default_context()
    if not verify:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    return ctx


class APICSession:
    """Cookie-based APIC REST session."""

    def __init__(self, base_url: str, username: str, password: str,
                 verify_ssl: bool = False, timeout: int = 30):
        self.base    = base_url.rstrip("/")
        self.timeout = timeout
        self._ctx    = _ssl_ctx(verify_ssl)
        self._cookie: str = ""
        self._login(username, password)

    def _login(self, username: str, password: str) -> None:
        payload = json.dumps({
            "aaaUser": {"attributes": {"name": username, "pwd": password}}
        }).encode()
        req = urllib.request.Request(
            f"{self.base}/api/aaaLogin.json",
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, context=self._ctx,
                                        timeout=self.timeout) as resp:
                body = json.loads(resp.read())
                token = (body.get("imdata", [{}])[0]
                         .get("aaaLogin", {})
                         .get("attributes", {})
                         .get("token", ""))
                if not token:
                    raise RuntimeError("Login OK but no token in response.")
                self._cookie = f"APIC-cookie={token}"
        except urllib.error.HTTPError as e:
            raise RuntimeError(
                f"APIC login failed ({e.code}): {e.read().decode()}"
            ) from e
        except urllib.error.URLError as e:
            raise RuntimeError(
                f"Cannot reach APIC at {self.base}: {e.reason}"
            ) from e

    def get(self, path: str, params: dict | None = None) -> Any:
        url = f"{self.base}{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers={"Cookie": self._cookie})
        with urllib.request.urlopen(req, context=self._ctx,
                                    timeout=self.timeout) as resp:
            return json.loads(resp.read())

    def post(self, path: str, body: dict) -> Any:
        payload = json.dumps(body).encode()
        req = urllib.request.Request(
            f"{self.base}{path}",
            data=payload,
            headers={"Cookie": self._cookie,
                     "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, context=self._ctx,
                                    timeout=self.timeout) as resp:
            return json.loads(resp.read())


class NDOSession:
    """Token-based NDO / Nexus Dashboard REST session."""

    def __init__(self, base_url: str, username: str, password: str,
                 verify_ssl: bool = False, timeout: int = 30):
        self.base    = base_url.rstrip("/")
        self.timeout = timeout
        self._ctx    = _ssl_ctx(verify_ssl)
        self._token: str = ""
        self._login(username, password)

    def _login(self, username: str, password: str) -> None:
        for domain in ("local", "DefaultAuth"):
            payload = json.dumps({
                "userName": username,
                "userPasswd": password,
                "domain": domain,
            }).encode()
            req = urllib.request.Request(
                f"{self.base}/login",
                data=payload,
                headers={"Content-Type": "application/json"},
            )
            try:
                with urllib.request.urlopen(req, context=self._ctx,
                                            timeout=self.timeout) as resp:
                    body = json.loads(resp.read())
                    tok  = body.get("token") or body.get("jwttoken")
                    if tok:
                        self._token = tok
                        return
            except (urllib.error.HTTPError, urllib.error.URLError):
                continue
        raise RuntimeError(
            f"NDO login failed at {self.base} (tried local + DefaultAuth)."
        )

    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {self._token}",
                "Content-Type": "application/json"}

    def get(self, path: str) -> Any:
        req = urllib.request.Request(
            f"{self.base}{path}", headers=self._headers()
        )
        with urllib.request.urlopen(req, context=self._ctx,
                                    timeout=self.timeout) as resp:
            return json.loads(resp.read())

    def post(self, path: str, body: dict) -> Any:
        payload = json.dumps(body).encode()
        req = urllib.request.Request(
            f"{self.base}{path}",
            data=payload,
            headers=self._headers(),
        )
        with urllib.request.urlopen(req, context=self._ctx,
                                    timeout=self.timeout) as resp:
            return json.loads(resp.read())


# ─────────────────────────────────────────────────────────────────────────────
# Health check functions — return {"status", "detail", "value"}
# ─────────────────────────────────────────────────────────────────────────────

TENANT = "AFR-DEL.Services"


def check_apic_cluster(s: APICSession, site: str) -> dict:
    """All APIC nodes must be fully-fit."""
    healthy_r = s.get("/api/class/infraWiNode.json",
                      {"query-target-filter": 'eq(infraWiNode.health,"fully-fit")'})
    all_r     = s.get("/api/class/infraWiNode.json")
    healthy = len(healthy_r.get("imdata", []))
    total   = len(all_r.get("imdata", []))
    value   = {"healthy": healthy, "total": total}
    if total == 0:
        return {"status": "warn",
                "detail": "No APIC nodes returned — check MO path",
                "value": value}
    if healthy < total:
        return {"status": "fail",
                "detail": f"{healthy}/{total} APIC nodes fully-fit",
                "value": value}
    return {"status": "pass",
            "detail": f"All {total} APIC nodes fully-fit",
            "value": value}


def check_faults(s: APICSession, site: str) -> dict:
    """No critical faults; warn on majors."""
    def _count(r: dict) -> int:
        try:
            return int(r["imdata"][0]["moCount"]["attributes"]["count"])
        except (KeyError, IndexError, ValueError):
            return -1

    n_crit  = _count(s.get("/api/class/faultInst.json",
                            {"query-target-filter": 'eq(faultInst.severity,"critical")',
                             "rsp-subtree-include": "count"}))
    n_major = _count(s.get("/api/class/faultInst.json",
                            {"query-target-filter": 'eq(faultInst.severity,"major")',
                             "rsp-subtree-include": "count"}))
    value = {"critical": n_crit, "major": n_major}

    if n_crit > 0:
        return {"status": "fail",
                "detail": f"{n_crit} critical fault(s) — resolve before proceeding",
                "value": value}
    if n_major > 0:
        return {"status": "warn",
                "detail": f"0 critical / {n_major} major fault(s) — review before proceeding",
                "value": value}
    return {"status": "pass", "detail": "No critical or major faults", "value": value}


def check_object_counts(s: APICSession, site: str) -> dict:
    """Count EPGs, BDs, VRFs under AFR-DEL.Services."""
    counts: dict[str, int] = {}
    for mo, label in [("fvAEPg", "epgs"), ("fvBD", "bds"), ("fvCtx", "vrfs")]:
        r = s.get(f"/api/class/{mo}.json",
                  {"query-target-filter": f'wcard({mo}.dn,"tn-{TENANT}")',
                   "rsp-subtree-include": "count"})
        try:
            counts[label] = int(r["imdata"][0]["moCount"]["attributes"]["count"])
        except (KeyError, IndexError, ValueError):
            counts[label] = -1

    zero = [k for k, v in counts.items() if v == 0]
    if zero:
        return {"status": "warn",
                "detail": f"Zero count for: {', '.join(zero)} — expected non-zero",
                "value": counts}
    return {"status": "pass",
            "detail": (f"EPGs={counts['epgs']}  "
                       f"BDs={counts['bds']}  "
                       f"VRFs={counts['vrfs']}"),
            "value": counts}


def check_bgp_peers(s: APICSession, site: str) -> dict:
    """BGP sessions — all should be established."""
    down_r = s.get("/api/class/bgpPeerEntry.json",
                   {"query-target-filter": 'ne(bgpPeerEntry.operSt,"established")'})
    all_r  = s.get("/api/class/bgpPeerEntry.json",
                   {"rsp-subtree-include": "count"})
    down = len(down_r.get("imdata", []))
    try:
        total = int(all_r["imdata"][0]["moCount"]["attributes"]["count"])
    except (KeyError, IndexError, ValueError):
        total = -1

    value = {"total": total, "down": down}
    if down > 0:
        dns = [p["bgpPeerEntry"]["attributes"]["dn"]
               for p in down_r["imdata"][:5]]
        return {"status": "fail",
                "detail": f"{down} BGP peer(s) not established: {dns}",
                "value": value}
    if total == 0:
        return {"status": "warn",
                "detail": "No BGP peers found — check border leaf reachability",
                "value": value}
    return {"status": "pass",
            "detail": f"All {total} BGP peer(s) established",
            "value": value}


def check_bgp_prefix_counts(s: APICSession, site: str) -> dict:
    """
    Phase 0.4 — collect per-VRF BGP prefix counts via APIC REST.
    Queries bgpDom (VRF-level BGP state) for prefix counts per address family.
    This supplements the ssh-based 'show bgp vpnv4 unicast all summary' from the
    implementation plan with a fully automated REST equivalent.
    """
    r = s.get("/api/class/bgpDom.json",
              {"query-target-filter": f'wcard(bgpDom.dn,"tn-{TENANT}")',
               "rsp-subtree": "children",
               "rsp-subtree-class": "bgpDomAf"})
    items = r.get("imdata", [])
    if not items:
        return {"status": "warn",
                "detail": f"No bgpDom entries found for {TENANT}",
                "value": {}}

    counts: dict[str, dict] = {}
    for item in items:
        vrf_dn = item.get("bgpDom", {}).get("attributes", {}).get("dn", "unknown")
        vrf_name = vrf_dn.split("/")[-1].replace("dom-", "")
        afs: dict[str, dict] = {}
        for child in item.get("bgpDom", {}).get("children", []):
            af_attr = child.get("bgpDomAf", {}).get("attributes", {})
            af_type = af_attr.get("type", "unknown")
            afs[af_type] = {
                "num_paths": af_attr.get("numPaths", "0"),
                "num_peers": af_attr.get("numPeers", "0"),
            }
        counts[vrf_name] = afs

    total_paths = sum(
        int(af.get("num_paths", 0))
        for vrf in counts.values()
        for af in vrf.values()
    )
    return {"status": "pass",
            "detail": (f"{len(counts)} VRF BGP domain(s) found — "
                       f"{total_paths} total paths"),
            "value": counts}


def check_vmm_domains(s: APICSession, site: str) -> dict:
    """VMM domain controllers should all be connected."""
    r           = s.get("/api/class/vmmCtrlrP.json")
    controllers = r.get("imdata", [])
    if not controllers:
        return {"status": "warn",
                "detail": "No VMM controllers found",
                "value": {"total": 0, "offline": []}}

    offline = [
        c["vmmCtrlrP"]["attributes"]["dn"]
        for c in controllers
        if c["vmmCtrlrP"]["attributes"].get("operSt", "") != "online"
    ]
    value = {"total": len(controllers), "offline": offline}
    if offline:
        severity = "fail" if len(offline) == len(controllers) else "warn"
        return {"status": severity,
                "detail": (f"{len(offline)}/{len(controllers)} "
                           f"VMM controller(s) offline: {offline}"),
                "value": value}
    return {"status": "pass",
            "detail": f"All {len(controllers)} VMM controller(s) online",
            "value": value}


def check_fabric_settings(s: APICSession, site: str) -> dict:
    """Fabric-wide settings audit — Remote EP Learning target state."""
    r = s.get("/api/mo/uni/infra/settings.json")
    try:
        attr = r["imdata"][0]["infraSetPol"]["attributes"]
    except (KeyError, IndexError):
        return {"status": "warn",
                "detail": "Could not read infraSetPol",
                "value": {}}

    rel   = attr.get("unicastXrEpLearnDisable", "no")
    value = {"remote_ep_learn_disabled": rel}
    if rel != "yes":
        return {"status": "warn",
                "detail": "Remote EP Learning ENABLED — target: disabled (Phase 1.5)",
                "value": value}
    return {"status": "pass",
            "detail": "Remote EP Learning disabled (Phase 1.5 target met)",
            "value": value}


def check_endpoint_controls(s: APICSession, site: str) -> dict:
    """Rogue EP Control state."""
    r = s.get("/api/mo/uni/infra/epCtrlP-default.json")
    try:
        attr = r["imdata"][0]["epControlP"]["attributes"]
    except (KeyError, IndexError):
        return {"status": "warn",
                "detail": "Could not read epControlP-default",
                "value": {}}

    admin_st = attr.get("adminSt", "disabled")
    value    = {"rogue_ep_admin_state": admin_st}
    if admin_st != "enabled":
        return {"status": "warn",
                "detail": f"Rogue EP Control adminSt={admin_st} — target: enabled (Phase 1.1)",
                "value": value}
    return {"status": "pass",
            "detail": f"Rogue EP Control enabled",
            "value": value}


def check_ndo_schema(s: NDOSession, schema_name: str) -> dict:
    """AFRICOM NIPR schema present in NDO."""
    schemas = s.get("/api/v1/schemas").get("schemas", [])
    target  = next((x for x in schemas
                    if x.get("displayName") == schema_name), None)
    if not target:
        return {"status": "warn",
                "detail": f"Schema '{schema_name}' not found in NDO",
                "value": {}}

    full      = s.get(f"/api/v1/schemas/{target['id']}")
    templates = full.get("schema", {}).get("templates", [])
    summary   = {t["name"]: [st["siteId"] for st in t.get("sites", [])]
                 for t in templates}
    return {"status": "pass",
            "detail": (f"Schema found — {len(templates)} template(s): "
                       f"{list(summary.keys())}"),
            "value": {"schema_id": target["id"], "templates": summary}}


def check_ndo_deploy_status(s: NDOSession, schema_name: str) -> dict:
    """All templates in the schema should be deployed on both sites."""
    schemas = s.get("/api/v1/schemas").get("schemas", [])
    target  = next((x for x in schemas
                    if x.get("displayName") == schema_name), None)
    if not target:
        return {"status": "warn",
                "detail": f"Schema '{schema_name}' not found",
                "value": {}}

    full      = s.get(f"/api/v1/schemas/{target['id']}")
    templates = full.get("schema", {}).get("templates", [])
    not_ok    = []
    for t in templates:
        for site in t.get("sites", []):
            state = site.get("deploymentStatus", "unknown")
            if state not in ("deployed", ""):
                not_ok.append(f"{t['name']}@{site.get('siteId')} ({state})")

    if not_ok:
        return {"status": "warn",
                "detail": f"Not fully deployed: {not_ok}",
                "value": {"issues": not_ok}}
    return {"status": "pass",
            "detail": f"All {len(templates)} template(s) deployed",
            "value": {"template_count": len(templates)}}


# ─────────────────────────────────────────────────────────────────────────────
# Phase 0 action functions — write-side (snapshot, backup, export)
# ─────────────────────────────────────────────────────────────────────────────

def trigger_apic_snapshot(s: APICSession, site: str, label: str) -> dict:
    """
    Phase 0.1 — Create an APIC configuration export (snapshot) and poll
    until it completes or times out.

    The APIC REST model:
      POST /api/mo/uni/fabric/configexp-<name>.json
      Body: {"configExportP": {"attributes": {...}, "children": [{"configRsExportDestination": ...}]}}

    The export lands in the APIC's internal snapshot store (not a remote path)
    so no remote-destination object is needed. Admin → Import/Export shows it.
    """
    policy_name = f"auto-snapshot-{label}-{site}"
    body = {
        "configExportP": {
            "attributes": {
                "name": policy_name,
                "format": "json",
                "snapshot": "true",
                "adminSt": "triggered",   # trigger immediately
                "descr": f"Pre/post change snapshot — {label} — {site}",
            }
        }
    }
    try:
        s.post(f"/api/mo/uni/fabric/configexp-{policy_name}.json", body)
    except Exception as e:
        return {"status": "warn",
                "detail": f"Could not create snapshot policy: {e}",
                "value": {"policy": policy_name}}

    # Poll for completion (up to 90 s)
    for attempt in range(18):
        time.sleep(5)
        try:
            r = s.get(f"/api/mo/uni/fabric/configexp-{policy_name}.json",
                      {"rsp-subtree": "children",
                       "rsp-subtree-class": "configJobCont"})
            jobs = r.get("imdata", [{}])[0]
            job_attr = (jobs.get("configExportP", {})
                        .get("children", [{}])[0]
                        .get("configJobCont", {})
                        .get("attributes", {}))
            state = job_attr.get("operSt", "")
            if state == "success":
                artifact = job_attr.get("lastStTime", "")
                return {"status": "pass",
                        "detail": f"Snapshot complete — {policy_name}  {artifact}",
                        "value": {"policy": policy_name,
                                  "state": state,
                                  "artifact": artifact}}
            if state in ("failed", "error"):
                return {"status": "fail",
                        "detail": f"Snapshot FAILED (state={state})",
                        "value": {"policy": policy_name, "state": state}}
        except Exception:
            pass  # tolerate transient read errors while APIC is writing

    return {"status": "warn",
            "detail": f"Snapshot did not complete within 90 s — check APIC GUI",
            "value": {"policy": policy_name}}


def trigger_ndo_backup(s: NDOSession, label: str) -> dict:
    """
    Phase 0.2 — Trigger an NDO configuration backup and poll for completion.

    NDO REST:
      GET  /api/v1/backups/remoteLocations  → find the configured remote location ID
      POST /api/v1/backups                  → trigger a new backup job
      GET  /api/v1/backups                  → poll status

    Falls back gracefully if no remote location is configured (reports warn
    rather than fail — operator can still verify manually in the ND GUI).
    """
    # Find the first configured remote location
    remote_id   = ""
    remote_name = ""
    try:
        locs = s.get("/api/v1/backups/remoteLocations")
        all_locs = locs.get("remoteLocations", [])
        if all_locs:
            remote_id   = all_locs[0].get("id", "")
            remote_name = all_locs[0].get("name", "")
    except Exception as e:
        return {"status": "warn",
                "detail": f"Could not retrieve remote backup locations: {e}",
                "value": {}}

    if not remote_id:
        return {"status": "warn",
                "detail": ("No remote backup location configured in NDO — "
                           "Phase 6.2 fix required before backup can be automated"),
                "value": {}}

    backup_name = f"auto-{label}-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}"
    try:
        resp = s.post("/api/v1/backups", {
            "name":             backup_name,
            "backupType":       "config",
            "remoteLocationId": remote_id,
        })
        job_id = (resp.get("backup", {}).get("id")
                  or resp.get("id", ""))
    except Exception as e:
        return {"status": "warn",
                "detail": f"Backup POST failed: {e}",
                "value": {"remote": remote_name}}

    if not job_id:
        return {"status": "warn",
                "detail": "Backup triggered but no job ID returned — verify in ND GUI",
                "value": {"backup_name": backup_name, "remote": remote_name}}

    # Poll for completion (up to 3 minutes — NDO backups are typically < 60 s)
    for attempt in range(18):
        time.sleep(10)
        try:
            all_jobs = s.get("/api/v1/backups").get("backups", [])
            job = next((b for b in all_jobs if b.get("id") == job_id), None)
            if job:
                state = job.get("status", "")
                if state in ("completed", "success"):
                    return {"status": "pass",
                            "detail": (f"NDO backup complete — "
                                       f"{backup_name} → {remote_name}"),
                            "value": {"job_id": job_id,
                                      "backup_name": backup_name,
                                      "remote": remote_name,
                                      "state": state}}
                if state in ("failed", "error"):
                    return {"status": "fail",
                            "detail": f"NDO backup FAILED (state={state})",
                            "value": {"job_id": job_id, "state": state}}
        except Exception:
            pass

    return {"status": "warn",
            "detail": "NDO backup did not complete within 3 min — check ND GUI",
            "value": {"job_id": job_id, "backup_name": backup_name}}


def export_ndo_schema(s: NDOSession, schema_name: str,
                      artifacts_dir: str, label: str) -> dict:
    """
    Phase 0.6 — Download the full AFRICOM NIPR schema JSON and save it to
    the artifacts directory.  This is the rollback target for Phase 5 (template
    restructuring) and Phase 7 (V2 schema deploy).
    """
    schemas = s.get("/api/v1/schemas").get("schemas", [])
    target  = next((x for x in schemas
                    if x.get("displayName") == schema_name), None)
    if not target:
        return {"status": "warn",
                "detail": f"Schema '{schema_name}' not found — cannot export",
                "value": {}}

    try:
        full = s.get(f"/api/v1/schemas/{target['id']}")
    except Exception as e:
        return {"status": "warn",
                "detail": f"Schema GET failed: {e}",
                "value": {}}

    safe_name = schema_name.replace(" ", "-").lower()
    filename  = f"ndo-schema-{safe_name}-{label}.json"
    out_path  = os.path.join(artifacts_dir, filename)
    os.makedirs(artifacts_dir, exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(full, f, indent=2)

    templates = full.get("schema", {}).get("templates", [])
    return {"status": "pass",
            "detail": (f"Schema exported — {len(templates)} template(s) → "
                       f"{out_path}"),
            "value": {"path": out_path,
                      "schema_id": target["id"],
                      "template_count": len(templates)}}


# ─────────────────────────────────────────────────────────────────────────────
# Output helpers
# ─────────────────────────────────────────────────────────────────────────────

def print_section(title: str) -> None:
    print(f"\n{BOLD(title)}")
    print("─" * 64)


def print_result(name: str, result: dict) -> None:
    icon   = STATUS_ICON.get(result["status"], "?")
    label  = STATUS_LABEL.get(result["status"], result["status"])
    detail = result.get("detail", "")
    print(f"  {icon}  {label:<6}  {name:<38}  {INFO(detail)}")


def compare_baselines(old: dict, new: dict) -> list[str]:
    """Return human-readable drift lines between two saved baselines."""
    drifts = []
    # Per-site numeric checks
    numeric_checks = [
        ("apic_cluster",   "value.healthy"),
        ("faults",         "value.critical"),
        ("faults",         "value.major"),
        ("object_counts",  "value.epgs"),
        ("object_counts",  "value.bds"),
        ("object_counts",  "value.vrfs"),
        ("bgp_peers",      "value.total"),
        ("bgp_peers",      "value.down"),
        ("vmm_domains",    "value.total"),
        ("vmm_domains",    "value.offline"),
        ("fabric_settings","value.remote_ep_learn_disabled"),
    ]
    for site in ("kelley", "deldin"):
        for check, dotpath in numeric_checks:
            def _dig(d: dict, path: str) -> Any:
                for key in path.split("."):
                    if not isinstance(d, dict):
                        return None
                    d = d.get(key)
                return d
            old_v = _dig(old.get("sites", {}).get(site, {}).get(check, {}),
                         dotpath.replace("value.", ""))
            new_v = _dig(new.get("sites", {}).get(site, {}).get(check, {}),
                         dotpath.replace("value.", ""))
            if old_v is None or new_v is None:
                continue
            if old_v != new_v:
                drifts.append(
                    f"{site}.{check}.{dotpath.split('.')[-1]}: "
                    f"{old_v}  →  {new_v}"
                )
    return drifts


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def _env(key: str, prompt: str, is_pw: bool = False) -> str:
    val = os.environ.get(key, "")
    if val:
        return val
    return getpass.getpass(f"{prompt}: ") if is_pw else input(f"{prompt}: ")


def build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="AFRICOM NIPR fabric health validation & Phase 0 automation.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    # ── APIC credentials
    g = p.add_argument_group("APIC credentials")
    g.add_argument("--kelley-url",      default="")
    g.add_argument("--kelley-user",     default="")
    g.add_argument("--kelley-password", default="")
    g.add_argument("--deldin-url",      default="")
    g.add_argument("--deldin-user",     default="")
    g.add_argument("--deldin-password", default="")
    # ── NDO credentials
    g2 = p.add_argument_group("NDO credentials")
    g2.add_argument("--ndo-url",      default="")
    g2.add_argument("--ndo-user",     default="")
    g2.add_argument("--ndo-password", default="")
    g2.add_argument("--skip-ndo",     action="store_true",
                    help="Skip all NDO checks and actions")
    # ── Output
    g3 = p.add_argument_group("Output")
    g3.add_argument("--output", "-o", default="",
                    help="Path for baseline JSON (default: scripts/baseline/<ts>.json)")
    g3.add_argument("--no-save", action="store_true",
                    help="Do not save a baseline JSON")
    g3.add_argument("--compare", "-c", default="",
                    help="Previous baseline JSON to diff against")
    g3.add_argument("--artifacts-dir", default="",
                    help="Directory for snapshots, schema exports, etc. "
                         "(default: same dir as --output or scripts/baseline/<ts>/)")
    # ── Phase 0 actions
    g4 = p.add_argument_group("Phase 0 actions")
    g4.add_argument("--phase0", action="store_true",
                    help="Enable all Phase 0 write actions: "
                         "--snapshot --backup-ndo --export-schema")
    g4.add_argument("--snapshot", action="store_true",
                    help="0.1  Trigger APIC config snapshot on both sites")
    g4.add_argument("--backup-ndo", action="store_true",
                    help="0.2  Trigger NDO configuration backup")
    g4.add_argument("--export-schema", action="store_true",
                    help="0.6  Export AFRICOM NIPR schema JSON to artifacts dir")
    # ── Misc
    p.add_argument("--schema", default="AFRICOM NIPR",
                   help="NDO schema display name to check (default: 'AFRICOM NIPR')")
    p.add_argument("--label", default="",
                   help="Label used in snapshot/backup names (default: timestamp)")
    return p


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main() -> int:
    args = build_argparser().parse_args()

    # --phase0 is a shorthand for all write actions
    if args.phase0:
        args.snapshot      = True
        args.backup_ndo    = True
        args.export_schema = True

    timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    label     = args.label or timestamp

    # Resolve credentials
    kelley_url  = args.kelley_url  or _env("KELLEY_APIC_URL",      "Kelley APIC URL")
    kelley_user = args.kelley_user or _env("KELLEY_APIC_USERNAME",  "Kelley APIC username")
    kelley_pw   = args.kelley_password or _env("KELLEY_APIC_PASSWORD",
                                               "Kelley APIC password", True)
    deldin_url  = args.deldin_url  or _env("DELDIN_APIC_URL",      "Del Din APIC URL")
    deldin_user = args.deldin_user or _env("DELDIN_APIC_USERNAME",  "Del Din APIC username")
    deldin_pw   = args.deldin_password or _env("DELDIN_APIC_PASSWORD",
                                               "Del Din APIC password", True)

    ndo_url = ndo_user = ndo_pw = ""
    if not args.skip_ndo:
        ndo_url  = args.ndo_url  or _env("NDO_URL",      "NDO URL")
        ndo_user = args.ndo_user or _env("NDO_USERNAME", "NDO username")
        ndo_pw   = args.ndo_password or _env("NDO_PASSWORD", "NDO password", True)

    # Resolve artifact directory
    if args.artifacts_dir:
        artifacts_dir = args.artifacts_dir
    else:
        script_dir    = os.path.dirname(os.path.abspath(__file__))
        artifacts_dir = os.path.join(script_dir, "baseline", timestamp)
    os.makedirs(artifacts_dir, exist_ok=True)

    print(BOLD(f"\nAFRICOM NIPR — Validation & Phase 0  [{timestamp}]"))
    print("=" * 64)

    baseline: dict = {
        "timestamp":    timestamp,
        "label":        label,
        "sites":        {"kelley": {}, "deldin": {}},
        "ndo":          {},
        "phase0_actions": {},
    }
    overall_status = "pass"

    def _upd(s: str) -> None:
        nonlocal overall_status
        if s == "fail" or (s == "warn" and overall_status == "pass"):
            overall_status = s

    # ── Phase 0.1 — APIC snapshots ────────────────────────────────────────────
    sites_cfg = [
        ("kelley", "Kelley (NADE02)", kelley_url, kelley_user, kelley_pw),
        ("deldin", "Del Din (NAIT03)", deldin_url, deldin_user, deldin_pw),
    ]

    for site_key, site_label, url, user, pw in sites_cfg:
        print_section(f"APIC — {site_label}")

        try:
            sess = APICSession(url, user, pw)
        except RuntimeError as e:
            print(f"  {FAIL('ERROR')}  Cannot authenticate: {e}")
            baseline["sites"][site_key]["error"] = str(e)
            overall_status = "fail"
            continue

        # Phase 0.1 snapshot (optional)
        if args.snapshot:
            result = trigger_apic_snapshot(sess, site_key, label)
            print_result("0.1 apic_snapshot", result)
            baseline["phase0_actions"][f"snapshot_{site_key}"] = result
            _upd(result["status"])

        # Health checks
        checks = [
            ("apic_cluster",        check_apic_cluster,        (sess, site_key)),
            ("faults",              check_faults,               (sess, site_key)),
            ("object_counts",       check_object_counts,        (sess, site_key)),
            ("bgp_peers",           check_bgp_peers,            (sess, site_key)),
            ("bgp_prefix_counts",   check_bgp_prefix_counts,    (sess, site_key)),
            ("vmm_domains",         check_vmm_domains,          (sess, site_key)),
            ("fabric_settings",     check_fabric_settings,      (sess, site_key)),
            ("endpoint_controls",   check_endpoint_controls,    (sess, site_key)),
        ]
        for key, fn, fn_args in checks:
            try:
                result = fn(*fn_args)
            except Exception as exc:
                result = {"status": "warn",
                          "detail": f"Check error: {exc}",
                          "value": None}
            print_result(key, result)
            baseline["sites"][site_key][key] = result
            _upd(result["status"])

    # ── NDO section ───────────────────────────────────────────────────────────
    if not args.skip_ndo:
        print_section("NDO — Nexus Dashboard Orchestrator")
        try:
            ndo = NDOSession(ndo_url, ndo_user, ndo_pw)

            # Phase 0.2 — trigger NDO backup (optional)
            if args.backup_ndo:
                result = trigger_ndo_backup(ndo, label)
                print_result("0.2 ndo_backup", result)
                baseline["phase0_actions"]["ndo_backup"] = result
                _upd(result["status"])

            # Phase 0.6 — export schema JSON (optional)
            if args.export_schema:
                result = export_ndo_schema(ndo, args.schema,
                                           artifacts_dir, label)
                print_result("0.6 ndo_schema_export", result)
                baseline["phase0_actions"]["ndo_schema_export"] = result
                _upd(result["status"])

            # Health checks
            ndo_checks = [
                ("schema_exists",    check_ndo_schema,        (ndo, args.schema)),
                ("deploy_status",    check_ndo_deploy_status, (ndo, args.schema)),
            ]
            for key, fn, fn_args in ndo_checks:
                try:
                    result = fn(*fn_args)
                except Exception as exc:
                    result = {"status": "warn",
                              "detail": f"Check error: {exc}",
                              "value": None}
                print_result(key, result)
                baseline["ndo"][key] = result
                _upd(result["status"])

        except RuntimeError as e:
            print(f"  {FAIL('ERROR')}  Cannot authenticate to NDO: {e}")
            baseline["ndo"]["error"] = str(e)
            overall_status = "fail"
    else:
        print(f"\n  {WARN('SKIP')}  NDO checks/actions skipped (--skip-ndo)")

    # ── Drift comparison ──────────────────────────────────────────────────────
    if args.compare:
        print_section(f"Drift vs {args.compare}")
        try:
            with open(args.compare) as f:
                old = json.load(f)
            drifts = compare_baselines(old, baseline)
            if drifts:
                for d in drifts:
                    print(f"  {WARN('DRIFT')}  {d}")
                _upd("warn")
            else:
                print(f"  {PASS('✔')}  No drift detected vs baseline.")
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"  {WARN('WARN')}  Could not load comparison baseline: {e}")

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n" + "=" * 64)
    summary_map = {
        "pass": PASS("ALL CHECKS PASSED — safe to proceed to next phase."),
        "warn": WARN("WARNINGS present — review before proceeding."),
        "fail": FAIL("CRITICAL FAILURES — do not proceed until resolved."),
    }
    print(f"  {summary_map[overall_status]}")

    # ── Save baseline JSON ────────────────────────────────────────────────────
    if not args.no_save:
        out_path = args.output
        if not out_path:
            out_path = os.path.join(artifacts_dir, f"baseline-{timestamp}.json")
        with open(out_path, "w") as f:
            json.dump(baseline, f, indent=2)
        print(f"\n  Baseline saved  → {INFO(out_path)}")
        if args.phase0 or args.snapshot or args.export_schema:
            print(f"  Artifacts dir   → {INFO(artifacts_dir)}")

    print()
    return 0 if overall_status in ("pass", "warn") else 1


if __name__ == "__main__":
    sys.exit(main())

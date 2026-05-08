#!/usr/bin/env python3
"""Standalone unit tests for generate_fi_bindings.py and check_fi_bindings_parity.py.

Run from this directory:

    python3 -m unittest test_fi_bindings -v

These tests exercise:
    * The schema-YAML parser (parse_epgs) and its VMM detection.
    * The --physical-only filter in generate_bindings().
    * The parity-check semantics (full vs physical-only modes, drift in
      both directions, unknown EPGs, warnings vs errors).

All tests are stdlib-only and write to tempfiles -- they never touch the
real schema YAML or manifest files.
"""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest.mock import patch

import generate_fi_bindings as gen
import check_fi_bindings_parity as parity


# Minimal schema YAML fixture that exercises every code path the parser
# cares about: an AppProf header, EPGs that define a YAML anchor with VMM,
# EPGs that reference the anchor, EPGs with inline VMM blocks, and EPGs
# with sites: spelled out without VMM (the physical-only pattern).
SCHEMA_FIXTURE = textwrap.dedent(
    """\
    ndo:
      schemas:
        - name: AEDCE-IPv4
          templates:
            - name: Tenant_EUR_IPv4
              application_profiles:
                - name: AppProf-AppCentric
                  endpoint_groups:
                    - name: EPG-VMM-ANCHOR
                      bridge_domain: { name: BD-VMM-ANCHOR }
                      sites: &epg_sites_internal
                        - name: AEDCG
                          vmware_vmm_domains:
                            - name: APCG-VDS1
                              deployment_immediacy: immediate
                              resolution_immediacy: immediate
                        - name: AEDCK
                          vmware_vmm_domains:
                            - name: APCK-VDS1
                              deployment_immediacy: immediate
                              resolution_immediacy: immediate
                    - name: EPG-VMM-REF
                      bridge_domain: { name: BD-VMM-REF }
                      sites: *epg_sites_internal
                    - name: EPG-VMM-INLINE
                      bridge_domain: { name: BD-VMM-INLINE }
                      sites:
                        - name: AEDCG
                          vmware_vmm_domains:
                            - name: APCG-VDS1
                        - name: AEDCK
                          vmware_vmm_domains:
                            - name: APCK-VDS1
                    - name: EPG-PHYS-1
                      bridge_domain: { name: BD-PHYS-1 }
                      # F5 BIG-IP -- physical, no VMM.
                      sites:
                        - name: AEDCG
                        - name: AEDCK
                    - name: EPG-PHYS-2
                      bridge_domain: { name: BD-PHYS-2 }
                      sites:
                        - name: AEDCG
                        - name: AEDCK
                - name: AppProf-DMZ
                  endpoint_groups:
                    - name: EPG-D64-PROXY
                      bridge_domain: { name: BD-D64-PROXY }
                      sites: *epg_sites_internal
    """
)


def _write_fixture(tmpdir: str, content: str = SCHEMA_FIXTURE) -> str:
    path = os.path.join(tmpdir, "schema.nac.yaml")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return path


class TestParseEpgsVmmDetection(unittest.TestCase):
    """parse_epgs() returns has_vmm correctly for every EPG pattern."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.schema = _write_fixture(self._tmp.name)

    def test_total_epg_count(self) -> None:
        epgs = gen.parse_epgs(self.schema)
        # 3 VMM (anchor + ref + inline) + 2 phys + 1 DMZ = 6
        self.assertEqual(len(epgs), 6)

    def test_vmm_anchor_definition_detected(self) -> None:
        epgs = {e["epg"]: e for e in gen.parse_epgs(self.schema)}
        self.assertTrue(epgs["EPG-VMM-ANCHOR"]["has_vmm"])

    def test_vmm_anchor_reference_detected(self) -> None:
        epgs = {e["epg"]: e for e in gen.parse_epgs(self.schema)}
        self.assertTrue(epgs["EPG-VMM-REF"]["has_vmm"])

    def test_vmm_inline_block_detected(self) -> None:
        epgs = {e["epg"]: e for e in gen.parse_epgs(self.schema)}
        self.assertTrue(epgs["EPG-VMM-INLINE"]["has_vmm"])

    def test_physical_epgs_have_no_vmm(self) -> None:
        epgs = {e["epg"]: e for e in gen.parse_epgs(self.schema)}
        self.assertFalse(epgs["EPG-PHYS-1"]["has_vmm"])
        self.assertFalse(epgs["EPG-PHYS-2"]["has_vmm"])

    def test_dmz_epg_via_anchor_ref_has_vmm(self) -> None:
        epgs = {e["epg"]: e for e in gen.parse_epgs(self.schema)}
        self.assertTrue(epgs["EPG-D64-PROXY"]["has_vmm"])

    def test_app_profile_assignment(self) -> None:
        epgs = {e["epg"]: e for e in gen.parse_epgs(self.schema)}
        self.assertEqual(epgs["EPG-VMM-ANCHOR"]["app_profile"], "AppProf-AppCentric")
        self.assertEqual(epgs["EPG-D64-PROXY"]["app_profile"], "AppProf-DMZ")

    def test_real_schema_counts(self) -> None:
        """Sanity check against the real schema-aedce-ipv4 file: 39 total,
        36 VMM-bound, 3 physical (EPG-LB / EPG-LMR / EPG-VHOST-MGMT)."""
        here = os.path.dirname(os.path.abspath(__file__))
        real = os.path.normpath(
            os.path.join(here, "..", "data", "nac-ndo", "schema-aedce-ipv4.nac.yaml")
        )
        if not os.path.isfile(real):
            self.skipTest(f"real schema not present at {real}")
        epgs = gen.parse_epgs(real)
        names = {e["epg"]: e["has_vmm"] for e in epgs}
        self.assertEqual(len(epgs), 39)
        self.assertEqual(sum(1 for e in epgs if e["has_vmm"]), 36)
        for phys in ("EPG-LB", "EPG-LMR", "EPG-VHOST-MGMT"):
            self.assertIn(phys, names, f"{phys} missing from real schema")
            self.assertFalse(names[phys], f"{phys} unexpectedly flagged has_vmm=True")


class TestGenerateBindingsPhysicalOnly(unittest.TestCase):
    """The --physical-only filter skips VMM-bound EPGs."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.schema = _write_fixture(self._tmp.name)
        self.epgs = gen.parse_epgs(self.schema)

    def test_full_mode_emits_for_every_epg(self) -> None:
        bindings, _missing, skipped = gen.generate_bindings(
            epgs=self.epgs,
            sites_filter=["AEDCG", "AEDCK"],
            vlan_map={},
            deployment_immediacy="immediate",
            mode="regular",
            skip_dmz=False,
            dmz_epgs=gen.DEFAULT_DMZ_EPGS,
            physical_only=False,
        )
        # 6 EPGs * 2 sites * 2 PCs = 24
        self.assertEqual(len(bindings), 24)
        self.assertEqual(skipped, [])

    def test_physical_only_emits_only_for_phys_epgs(self) -> None:
        bindings, _missing, skipped = gen.generate_bindings(
            epgs=self.epgs,
            sites_filter=["AEDCG", "AEDCK"],
            vlan_map={},
            deployment_immediacy="immediate",
            mode="regular",
            skip_dmz=False,
            dmz_epgs=gen.DEFAULT_DMZ_EPGS,
            physical_only=True,
        )
        # 2 phys EPGs * 2 sites * 2 PCs = 8
        self.assertEqual(len(bindings), 8)
        self.assertCountEqual(skipped, [
            "EPG-VMM-ANCHOR", "EPG-VMM-REF", "EPG-VMM-INLINE", "EPG-D64-PROXY",
        ])
        # All emitted bindings reference physical EPGs only.
        emitted_epgs = {b["epg_name"] for b in bindings}
        self.assertEqual(emitted_epgs, {"EPG-PHYS-1", "EPG-PHYS-2"})

    def test_skip_dmz_combines_with_physical_only(self) -> None:
        # AppProf-DMZ has only EPG-D64-PROXY here, which is also VMM. Either
        # filter alone removes it; both together should still remove it
        # (and not double-count anything).
        bindings, _missing, skipped = gen.generate_bindings(
            epgs=self.epgs,
            sites_filter=["AEDCG"],
            vlan_map={},
            deployment_immediacy="immediate",
            mode="regular",
            skip_dmz=True,
            dmz_epgs=gen.DEFAULT_DMZ_EPGS,
            physical_only=True,
        )
        emitted = {b["epg_name"] for b in bindings}
        self.assertEqual(emitted, {"EPG-PHYS-1", "EPG-PHYS-2"})

    def test_physical_only_path_type_is_dpc(self) -> None:
        bindings, _missing, _skipped = gen.generate_bindings(
            epgs=self.epgs,
            sites_filter=["AEDCG"],
            vlan_map={},
            deployment_immediacy="immediate",
            mode="regular",
            skip_dmz=False,
            dmz_epgs=gen.DEFAULT_DMZ_EPGS,
            physical_only=True,
        )
        # Every binding emitted by this script uses dpc, not vpc -- the
        # FI port-channels are single-homed.
        for b in bindings:
            self.assertEqual(b["path_type"], "dpc")
            self.assertIn("PC_FI_", b["path"])


class TestParityCheck(unittest.TestCase):
    """The parity checker correctly catches drift in both directions."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.schema = _write_fixture(self._tmp.name)
        self.schema_epgs = gen.parse_epgs(self.schema)
        self.all_epg_names = {e["epg"] for e in self.schema_epgs}
        self.phys_epg_names = {e["epg"] for e in self.schema_epgs if not e["has_vmm"]}

    def _write_manifest(self, mode: str, epgs: list[str], skip_dmz: bool = False) -> str:
        path = os.path.join(self._tmp.name, f"manifest_{mode}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "schema_yaml": self.schema,
                    "mode": mode,
                    "skip_dmz": skip_dmz,
                    "epgs": sorted(epgs),
                },
                f,
            )
        return path

    def _run_parity(self, manifest_path: str) -> tuple[int, str, str]:
        out = io.StringIO()
        err = io.StringIO()
        argv = [
            "check_fi_bindings_parity.py",
            "--schema-yaml",
            self.schema,
            "--manifest",
            manifest_path,
        ]
        with patch.object(sys, "argv", argv), redirect_stdout(out), redirect_stderr(err):
            try:
                rc = parity.main()
            except SystemExit as e:
                # Python: SystemExit with int -> that's the code; with None
                # -> 0; with any other type (e.g. string error message) ->
                # the message goes to stderr and the exit code is 1.
                if e.code is None:
                    rc = 0
                elif isinstance(e.code, int):
                    rc = e.code
                else:
                    err.write(str(e.code) + "\n")
                    rc = 1
        return rc, out.getvalue(), err.getvalue()

    def test_full_mode_parity_passes(self) -> None:
        manifest = self._write_manifest("full", list(self.all_epg_names))
        rc, stdout, _stderr = self._run_parity(manifest)
        self.assertEqual(rc, 0)
        self.assertIn("OK: schema and manifest are in parity", stdout)

    def test_full_mode_missing_epg_fails(self) -> None:
        epgs = list(self.all_epg_names - {"EPG-PHYS-1"})
        manifest = self._write_manifest("full", epgs)
        rc, _stdout, stderr = self._run_parity(manifest)
        self.assertEqual(rc, 1)
        self.assertIn("MISSING from the manifest", stderr)
        self.assertIn("EPG-PHYS-1", stderr)

    def test_full_mode_unknown_epg_fails(self) -> None:
        epgs = list(self.all_epg_names) + ["EPG-DOES-NOT-EXIST"]
        manifest = self._write_manifest("full", epgs)
        rc, _stdout, stderr = self._run_parity(manifest)
        self.assertEqual(rc, 1)
        self.assertIn("NOT in the schema", stderr)
        self.assertIn("EPG-DOES-NOT-EXIST", stderr)
        self.assertIn("(unknown to schema)", stderr)

    def test_full_mode_typo_drift_in_both_directions(self) -> None:
        epgs = list(self.all_epg_names - {"EPG-VMM-REF"}) + ["EPG-VMM-REFF"]
        manifest = self._write_manifest("full", epgs)
        rc, _stdout, stderr = self._run_parity(manifest)
        self.assertEqual(rc, 1)
        self.assertIn("MISSING", stderr)
        self.assertIn("EPG-VMM-REF", stderr)
        self.assertIn("EPG-VMM-REFF", stderr)

    def test_physical_only_mode_parity_passes(self) -> None:
        manifest = self._write_manifest("physical-only", list(self.phys_epg_names))
        rc, stdout, _stderr = self._run_parity(manifest)
        self.assertEqual(rc, 0)
        self.assertIn("OK: schema and manifest are in parity", stdout)

    def test_physical_only_mode_missing_phys_epg_fails(self) -> None:
        manifest = self._write_manifest("physical-only", ["EPG-PHYS-1"])
        rc, _stdout, stderr = self._run_parity(manifest)
        self.assertEqual(rc, 1)
        self.assertIn("MISSING from the manifest", stderr)
        self.assertIn("EPG-PHYS-2", stderr)

    def test_physical_only_mode_stray_vmm_epg_warns_but_passes(self) -> None:
        # Listing a VMM EPG in physical-only mode is a warning, not an
        # error: it just means the operator opted into Approach 2 for that
        # specific EPG. The check stays exit 0 so this isn't disruptive.
        manifest = self._write_manifest(
            "physical-only", list(self.phys_epg_names) + ["EPG-VMM-REF"]
        )
        rc, _stdout, stderr = self._run_parity(manifest)
        self.assertEqual(rc, 0)
        self.assertIn("WARNING", stderr)
        self.assertIn("EPG-VMM-REF", stderr)

    def test_invalid_mode_rejected(self) -> None:
        manifest = self._write_manifest("nonsense", ["EPG-PHYS-1"])
        rc, _stdout, _stderr = self._run_parity(manifest)
        self.assertEqual(rc, 2)

    def test_missing_manifest_rejected(self) -> None:
        rc, _stdout, _stderr = self._run_parity(
            os.path.join(self._tmp.name, "does_not_exist.json")
        )
        self.assertEqual(rc, 2)

    def test_malformed_manifest_rejected(self) -> None:
        path = os.path.join(self._tmp.name, "broken.json")
        with open(path, "w", encoding="utf-8") as f:
            f.write("{not valid json")
        rc, _stdout, _stderr = self._run_parity(path)
        self.assertEqual(rc, 2)


class TestCommittedManifestParity(unittest.TestCase):
    """The committed fi_epg_manifest.json must be in parity with the real
    schema. This is the test that fails locally if you forget to regenerate
    the manifest -- the same condition CI catches at merge time."""

    def test_committed_manifest_matches_real_schema(self) -> None:
        here = os.path.dirname(os.path.abspath(__file__))
        manifest_path = os.path.join(here, "fi_epg_manifest.json")
        if not os.path.isfile(manifest_path):
            self.skipTest("no committed manifest yet")
        # Run the real parity check against the real artifacts.
        result = subprocess.run(
            [sys.executable, os.path.join(here, "check_fi_bindings_parity.py")],
            capture_output=True,
            text=True,
            cwd=here,
        )
        self.assertEqual(
            result.returncode,
            0,
            f"committed manifest is out of parity with the schema:\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )


if __name__ == "__main__":
    unittest.main()

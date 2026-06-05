#!/usr/bin/env bash
# cleanup-old-vmm-domain.sh
#
# One-shot helper to delete the legacy operationally-inert VMM domain
# `vmm-vcenter-rcc` from one or both lab APICs before re-applying with the
# new per-fabric VMM domain names (APCG-VDS1, APCK-VDS1).
#
# Why this exists:
#   - The previous design used a single shared VMM domain `vmm-vcenter-rcc`
#     pointing at vCenter 8.0.2 with dvsVersion=6.6 (an invalid combination).
#   - APIC accepted the config but never created a VDS in vCenter
#     (compDom=0, vmmEpPD=0). The 39 fvRsDomAtt pushed by NDO are dangling.
#   - We now want APIC to instead adopt the pre-existing per-fabric VDSes
#     (APCG-VDS1 on Site1, APCK-VDS1 on Site2), which requires the new VMM
#     domain names. Letting Terraform destroy the old `vmm-vcenter-rcc`
#     during apply hangs because EPG fvRsDomAtt entries still reference it.
#   - Deleting the old VMM domain via REST first lets APIC GC the dangling
#     fvRsDomAtt and clears the F0135 faults; the subsequent
#     apic-vmware/ make apply -> ndo/ make apply sequence then runs clean.
#
# Usage:
#   ./cleanup-old-vmm-domain.sh site1
#   ./cleanup-old-vmm-domain.sh site2
#   ./cleanup-old-vmm-domain.sh both          (default)
#
# Required env vars (same names the rest of the project uses):
#   TF_VAR_site1_apic_password   (admin password for Site1 APIC)
#   TF_VAR_site2_apic_password   (admin password for Site2 APIC)
#
# This script ONLY deletes the legacy domain and verifies the delete; it
# does not touch any other APIC config and does not write anything to disk.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OLD_DOMAIN="vmm-vcenter-rcc"
TFVARS="terraform.tfvars"

read_tfvar() {
  local key="$1"
  awk -F '=' -v key="$key" '$0 ~ "^[[:space:]]*"key"[[:space:]]*=" {gsub(/[ "\r]/, "", $2); print $2; exit}' "$TFVARS"
}

cleanup_one() {
  local fabric="$1"
  local pwvar="TF_VAR_${fabric}_apic_password"
  local urlkey="${fabric}_apic_url"
  local userkey="${fabric}_apic_username"
  local pw url user payload tok code dn="uni/vmmp-VMware/dom-${OLD_DOMAIN}"

  pw="${!pwvar:-}"
  if [ -z "$pw" ]; then
    echo "cleanup ($fabric): $pwvar not set; skipping" >&2
    return 1
  fi

  url=$(read_tfvar  "$urlkey")
  user=$(read_tfvar "$userkey")
  if [ -z "$url" ] || [ -z "$user" ]; then
    echo "cleanup ($fabric): could not read $urlkey/$userkey from $TFVARS" >&2
    return 1
  fi

  echo "cleanup ($fabric): logging in to $url as $user"
  payload=$(PW="$pw" python3 -c 'import json, os, sys; print(json.dumps({"aaaUser":{"attributes":{"name":sys.argv[1],"pwd":os.environ["PW"]}}}))' "$user")
  tok=$(curl -k -sS --max-time 15 \
        -H 'Content-Type: application/json' \
        -X POST "$url/api/aaaLogin.json" \
        --data-binary "$payload" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["imdata"][0]["aaaLogin"]["attributes"]["token"])') || {
    echo "cleanup ($fabric): login failed" >&2
    return 1
  }

  # Probe before delete: how many fvRsDomAtt point at the old domain today?
  pre=$(curl -k -sS --max-time 15 \
        -H "Cookie: APIC-cookie=$tok" \
        "$url/api/node/class/fvRsDomAtt.json?query-target-filter=wcard(fvRsDomAtt.tDn,%22${OLD_DOMAIN}%22)" \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("totalCount","?"))')
  echo "cleanup ($fabric): pre-delete fvRsDomAtt -> $OLD_DOMAIN count = $pre"

  # Delete the VMM domain. Setting status=deleted causes APIC to garbage-
  # collect children (vmmCtrlrP, dangling fvRsDomAtt references in tenants).
  echo "cleanup ($fabric): DELETE $url/api/node/mo/$dn.json"
  code=$(curl -k -sS --max-time 30 -o /tmp/cleanup_resp.$$ -w '%{http_code}' \
        -H "Cookie: APIC-cookie=$tok" \
        -H 'Content-Type: application/json' \
        -X POST "$url/api/node/mo/$dn.json" \
        --data-binary "{\"vmmDomP\":{\"attributes\":{\"dn\":\"$dn\",\"status\":\"deleted\"}}}")
  body=$(cat /tmp/cleanup_resp.$$ 2>/dev/null || true)
  rm -f /tmp/cleanup_resp.$$
  echo "cleanup ($fabric): HTTP $code"
  if [ "$code" != "200" ]; then
    echo "cleanup ($fabric): APIC rejected delete: $body" >&2
    return 1
  fi

  # Verify gone.
  remain=$(curl -k -sS --max-time 15 \
        -H "Cookie: APIC-cookie=$tok" \
        "$url/api/node/mo/$dn.json" \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("totalCount","?"))')
  echo "cleanup ($fabric): post-delete vmmDomP/$OLD_DOMAIN count = $remain (expect 0)"
  if [ "$remain" != "0" ]; then
    echo "cleanup ($fabric): WARNING -- domain still present" >&2
    return 1
  fi

  echo "cleanup ($fabric): OK -- old VMM domain removed."
}

target="${1:-both}"
case "$target" in
  site1|site2) cleanup_one "$target" ;;
  both|"")
    rc=0
    cleanup_one site1 || rc=1
    echo
    cleanup_one site2 || rc=1
    exit "$rc"
    ;;
  *)
    echo "cleanup: unknown fabric '$target'. Use site1, site2, or both." >&2
    exit 2
    ;;
esac

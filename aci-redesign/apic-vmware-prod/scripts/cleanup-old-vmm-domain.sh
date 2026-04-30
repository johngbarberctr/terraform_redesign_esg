#!/usr/bin/env bash
# cleanup-old-vmm-domain.sh (apic-vmware-prod variant)
#
# Production sister of ../../apic-vmware/scripts/cleanup-old-vmm-domain.sh.
# Deletes a legacy VMM domain from the production APIC(s) BEFORE the first
# `make apply` of the apic-vmware-prod root, so APIC can garbage-collect
# any dangling fvRsDomAtt before the new per-fabric VMM domains
# (APCG-VDS1, APCK-VDS1) are pushed.
#
# The legacy production domain name is configurable via the OLD_DOMAIN env
# var (default `vmm-vcenter-rcc`, matching the lab cleanup helper). If the
# production APICs use a different legacy domain name (e.g. an older VMM
# domain pointing at vCenter pre-redesign), set OLD_DOMAIN to that.
#
# Usage:
#   OLD_DOMAIN=vmm-vcenter-rcc  ./cleanup-old-vmm-domain.sh aedcg
#   OLD_DOMAIN=vmm-vcenter-rcc  ./cleanup-old-vmm-domain.sh aedck
#                                ./cleanup-old-vmm-domain.sh both
#
# Required env vars:
#   TF_VAR_aedcg_apic_password  (admin password for AEDCG production APIC)
#   TF_VAR_aedck_apic_password  (admin password for AEDCK production APIC)

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OLD_DOMAIN="${OLD_DOMAIN:-vmm-vcenter-rcc}"
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
    echo "cleanup ($fabric, prod): $pwvar not set; skipping" >&2
    return 1
  fi

  url=$(read_tfvar  "$urlkey")
  user=$(read_tfvar "$userkey")
  if [ -z "$url" ] || [ -z "$user" ]; then
    echo "cleanup ($fabric, prod): could not read $urlkey/$userkey from $TFVARS" >&2
    return 1
  fi

  echo "cleanup ($fabric, prod): logging in to $url as $user (target VMM domain: $OLD_DOMAIN)"
  payload=$(PW="$pw" python3 -c 'import json, os, sys; print(json.dumps({"aaaUser":{"attributes":{"name":sys.argv[1],"pwd":os.environ["PW"]}}}))' "$user")
  tok=$(curl -k -sS --max-time 15 \
        -H 'Content-Type: application/json' \
        -X POST "$url/api/aaaLogin.json" \
        --data-binary "$payload" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["imdata"][0]["aaaLogin"]["attributes"]["token"])') || {
    echo "cleanup ($fabric, prod): login failed" >&2
    return 1
  }

  pre=$(curl -k -sS --max-time 15 \
        -H "Cookie: APIC-cookie=$tok" \
        "$url/api/node/class/fvRsDomAtt.json?query-target-filter=wcard(fvRsDomAtt.tDn,%22${OLD_DOMAIN}%22)" \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("totalCount","?"))')
  echo "cleanup ($fabric, prod): pre-delete fvRsDomAtt -> $OLD_DOMAIN count = $pre"

  if [ "$pre" = "0" ]; then
    # Domain is already gone or never existed. Confirm and exit success.
    remain=$(curl -k -sS --max-time 15 \
          -H "Cookie: APIC-cookie=$tok" \
          "$url/api/node/mo/$dn.json" \
          | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("totalCount","?"))')
    if [ "$remain" = "0" ]; then
      echo "cleanup ($fabric, prod): $OLD_DOMAIN already absent on this APIC; nothing to do."
      return 0
    fi
  fi

  echo "cleanup ($fabric, prod): DELETE $url/api/node/mo/$dn.json"
  code=$(curl -k -sS --max-time 30 -o /tmp/cleanup_resp.$$ -w '%{http_code}' \
        -H "Cookie: APIC-cookie=$tok" \
        -H 'Content-Type: application/json' \
        -X POST "$url/api/node/mo/$dn.json" \
        --data-binary "{\"vmmDomP\":{\"attributes\":{\"dn\":\"$dn\",\"status\":\"deleted\"}}}")
  body=$(cat /tmp/cleanup_resp.$$ 2>/dev/null || true)
  rm -f /tmp/cleanup_resp.$$
  echo "cleanup ($fabric, prod): HTTP $code"
  if [ "$code" != "200" ]; then
    echo "cleanup ($fabric, prod): APIC rejected delete: $body" >&2
    return 1
  fi

  remain=$(curl -k -sS --max-time 15 \
        -H "Cookie: APIC-cookie=$tok" \
        "$url/api/node/mo/$dn.json" \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("totalCount","?"))')
  echo "cleanup ($fabric, prod): post-delete vmmDomP/$OLD_DOMAIN count = $remain (expect 0)"
  if [ "$remain" != "0" ]; then
    echo "cleanup ($fabric, prod): WARNING -- domain still present" >&2
    return 1
  fi

  echo "cleanup ($fabric, prod): OK -- legacy VMM domain $OLD_DOMAIN removed."
}

target="${1:-both}"
case "$target" in
  aedcg|aedck) cleanup_one "$target" ;;
  both|"")
    rc=0
    cleanup_one aedcg || rc=1
    echo
    cleanup_one aedck || rc=1
    exit "$rc"
    ;;
  *)
    echo "cleanup (prod): unknown fabric '$target'. Use aedcg, aedck, or both." >&2
    exit 2
    ;;
esac

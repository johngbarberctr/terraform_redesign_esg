#!/usr/bin/env bash
# auth-check.sh (apic-vmware-prod variant)
#
# POST /api/aaaLogin.json to a production fabric's APIC using the same
# identity Terraform would use: <fabric>_apic_url + <fabric>_apic_username
# from terraform.tfvars, and TF_VAR_<fabric>_apic_password from the env.
# Functionally identical to ../../apic-vmware/scripts/auth-check.sh; lives
# here so the prod root is self-contained.
#
# Usage:
#   ./auth-check.sh aedcg     # check AEDCG production
#   ./auth-check.sh aedck     # check AEDCK production
#   ./auth-check.sh           # check BOTH (default)
#   ./auth-check.sh both      # check BOTH (explicit)

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

check_one() {
  local fabric="$1"
  local pwvar="TF_VAR_${fabric}_apic_password"
  local urlkey="${fabric}_apic_url"
  local userkey="${fabric}_apic_username"
  local pw url user payload code

  pw="${!pwvar:-}"
  if [ -z "$pw" ]; then
    echo "auth-check ($fabric, prod): $pwvar is not set in this shell." >&2
    echo "  Export it (single quotes!) with:" >&2
    echo "    export $pwvar='<APIC admin password>'" >&2
    return 1
  fi

  url=$(awk -F '=' -v key="$urlkey" '$0 ~ "^[[:space:]]*"key"[[:space:]]*=" {gsub(/[ "\r]/, "", $2); print $2; exit}' terraform.tfvars)
  user=$(awk -F '=' -v key="$userkey" '$0 ~ "^[[:space:]]*"key"[[:space:]]*=" {gsub(/[ "\r]/, "", $2); print $2; exit}' terraform.tfvars)

  if [ -z "$url" ] || [ -z "$user" ]; then
    echo "auth-check ($fabric, prod): could not read $urlkey / $userkey from terraform.tfvars" >&2
    return 1
  fi

  payload=$(PW_VAL="$pw" python3 -c 'import json, os, sys; print(json.dumps({"aaaUser": {"attributes": {"name": sys.argv[1], "pwd": os.environ["PW_VAL"]}}}))' "$user") || {
    echo "auth-check ($fabric, prod): failed to build JSON payload (python3 missing?)" >&2
    return 1
  }

  echo "auth-check ($fabric, prod): POST $url/api/aaaLogin.json as $user (TLS verify disabled)"
  code=$(curl -k -sS -o /dev/null --max-time 15 -w '%{http_code}' \
         -H 'Content-Type: application/json' \
         -X POST "$url/api/aaaLogin.json" \
         --data-binary "$payload" 2>/dev/null || true)
  [ -z "$code" ] && code=000

  echo "auth-check ($fabric, prod): HTTP $code"
  case "$code" in
    200) echo "auth-check ($fabric, prod): OK -- APIC accepted credentials." ;;
    400|401)
      echo "auth-check ($fabric, prod): BAD CREDENTIALS -- APIC rejected username/password." >&2
      return 1 ;;
    403)
      echo "auth-check ($fabric, prod): FORBIDDEN -- account likely locked. Wait or unlock." >&2
      return 1 ;;
    000)
      echo "auth-check ($fabric, prod): NO RESPONSE -- $url unreachable / TLS / wrong host." >&2
      return 1 ;;
    *)
      echo "auth-check ($fabric, prod): unexpected HTTP $code." >&2
      return 1 ;;
  esac
}

target="${1:-both}"
case "$target" in
  aedcg|aedck) check_one "$target" ;;
  both|"")
    rc=0
    check_one aedcg || rc=1
    echo
    check_one aedck || rc=1
    exit "$rc"
    ;;
  *)
    echo "auth-check (prod): unknown fabric '$target'. Use aedcg, aedck, or both." >&2
    exit 2
    ;;
esac

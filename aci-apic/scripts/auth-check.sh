#!/usr/bin/env bash
# auth-check.sh
#
# POST /api/aaaLogin.json to a fabric's APIC using the same identity Terraform
# would use: <fabric>_apic_url + <fabric>_apic_username from terraform.tfvars,
# and TF_VAR_<fabric>_apic_password from the environment. The payload is
# built with python3's json.dumps so any '"', '\', '!', etc. in the password
# is safely quoted; the password is never printed. `curl -k` matches
# `<fabric>_apic_insecure = true` in providers.tf for self-signed lab APICs.
#
# Usage:
#   ./auth-check.sh aedcg     # check AEDCG only
#   ./auth-check.sh aedck     # check AEDCK only
#   ./auth-check.sh           # check BOTH (default)
#   ./auth-check.sh both      # check BOTH (explicit)
#
# Returns non-zero if any checked fabric fails; the Makefile's `make
# auth-check` target shells out to this script.

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
    echo "auth-check ($fabric): $pwvar is not set in this shell." >&2
    echo "  Export it (single quotes!) with:" >&2
    echo "    export $pwvar='<APIC admin password>'" >&2
    return 1
  fi

  url=$(awk -F '=' -v key="$urlkey" '$0 ~ "^[[:space:]]*"key"[[:space:]]*=" {gsub(/[ "\r]/, "", $2); print $2; exit}' terraform.tfvars)
  user=$(awk -F '=' -v key="$userkey" '$0 ~ "^[[:space:]]*"key"[[:space:]]*=" {gsub(/[ "\r]/, "", $2); print $2; exit}' terraform.tfvars)

  if [ -z "$url" ] || [ -z "$user" ]; then
    echo "auth-check ($fabric): could not read $urlkey / $userkey from terraform.tfvars" >&2
    return 1
  fi

  payload=$(PW_VAL="$pw" python3 -c 'import json, os, sys; print(json.dumps({"aaaUser": {"attributes": {"name": sys.argv[1], "pwd": os.environ["PW_VAL"]}}}))' "$user") || {
    echo "auth-check ($fabric): failed to build JSON payload (python3 missing?)" >&2
    return 1
  }

  echo "auth-check ($fabric): POST $url/api/aaaLogin.json as $user (TLS verify disabled)"
  code=$(curl -k -sS -o /dev/null --max-time 15 -w '%{http_code}' \
         -H 'Content-Type: application/json' \
         -X POST "$url/api/aaaLogin.json" \
         --data-binary "$payload" 2>/dev/null || true)
  [ -z "$code" ] && code=000

  echo "auth-check ($fabric): HTTP $code"
  case "$code" in
    200)
      echo "auth-check ($fabric): OK -- APIC accepted credentials."
      return 0
      ;;
    400|401)
      echo "auth-check ($fabric): BAD CREDENTIALS -- APIC rejected username/password." >&2
      echo "           Common causes: wrong password; bash history-expanded '!';" >&2
      echo "           trailing newline from copy-paste; wrong $userkey in tfvars." >&2
      echo "           Run: ./scripts/diagnose-apic-auth.sh $fabric" >&2
      return 1
      ;;
    403)
      echo "auth-check ($fabric): FORBIDDEN -- account likely locked by repeated failures." >&2
      echo "           Wait ~5-10 min or unlock via another admin." >&2
      return 1
      ;;
    000)
      echo "auth-check ($fabric): NO RESPONSE -- $url unreachable / TLS failure / wrong host." >&2
      echo "           Test reachability:" >&2
      echo "             curl -k -sS -o /dev/null -w 'HTTP %{http_code}' $url/api/aaaLogin.json; echo" >&2
      return 1
      ;;
    *)
      echo "auth-check ($fabric): unexpected HTTP $code. Inspect APIC aaaLogin response manually." >&2
      return 1
      ;;
  esac
}

target="${1:-both}"
case "$target" in
  aedcg|aedck)
    check_one "$target"
    ;;
  both)
    rc=0
    check_one aedcg || rc=1
    echo
    check_one aedck || rc=1
    exit "$rc"
    ;;
  "")
    rc=0
    check_one aedcg || rc=1
    echo
    check_one aedck || rc=1
    exit "$rc"
    ;;
  *)
    echo "auth-check: unknown fabric '$target'. Use aedcg, aedck, both, or no arg." >&2
    exit 2
    ;;
esac

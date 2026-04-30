#!/usr/bin/env bash
# auth-check.sh
#
# POST a login request to NDO/ND using the same identity Terraform would use:
# ndo_url + ndo_username from terraform.tfvars, and TF_VAR_ndo_password from
# the environment. The payload is built with python3's json.dumps so any '"',
# '\', '!', etc. in the password is safely quoted; the password is never
# printed. `curl -k` matches `ndo_insecure = true` in providers.tf for
# self-signed lab certs.
#
# Returns non-zero if the login fails. The Makefile's `make auth-check`
# target shells out to this script.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

pw="${TF_VAR_ndo_password:-}"
if [ -z "$pw" ]; then
  echo "auth-check: TF_VAR_ndo_password is not set in this shell." >&2
  echo "  Export it (single quotes!) with:" >&2
  echo "    export TF_VAR_ndo_password='<NDO admin password>'" >&2
  exit 1
fi

# Read non-sensitive values from terraform.tfvars.
url=$(awk -F '=' '$0 ~ /^[[:space:]]*ndo_url[[:space:]]*=/ {gsub(/[ "\r]/, "", $2); print $2; exit}'      terraform.tfvars)
user=$(awk -F '=' '$0 ~ /^[[:space:]]*ndo_username[[:space:]]*=/ {gsub(/[ "\r]/, "", $2); print $2; exit}' terraform.tfvars)
plat=$(awk -F '=' '$0 ~ /^[[:space:]]*ndo_platform[[:space:]]*=/ {gsub(/[ "\r]/, "", $2); print $2; exit}' terraform.tfvars)
domain=$(awk -F '=' '$0 ~ /^[[:space:]]*ndo_domain[[:space:]]*=/ {gsub(/[ "\r]/, "", $2); print $2; exit}'  terraform.tfvars)
plat="${plat:-nd}"
domain="${domain:-local}"

if [ -z "$url" ] || [ -z "$user" ]; then
  echo "auth-check: could not read ndo_url / ndo_username from terraform.tfvars" >&2
  exit 1
fi

# ND (Nexus Dashboard) and standalone MSO use different login endpoints and
# payload shapes. Match the provider behaviour.
if [ "$plat" = "nd" ]; then
  endpoint="$url/login"
  payload=$(PW_VAL="$pw" python3 -c 'import json, os, sys; print(json.dumps({"userName": sys.argv[1], "userPasswd": os.environ["PW_VAL"], "domain": sys.argv[2]}))' "$user" "$domain") \
    || { echo "auth-check: failed to build JSON payload (python3 missing?)" >&2; exit 1; }
else
  endpoint="$url/api/v1/auth/login"
  payload=$(PW_VAL="$pw" python3 -c 'import json, os, sys; print(json.dumps({"username": sys.argv[1], "password": os.environ["PW_VAL"], "domain": sys.argv[2]}))' "$user" "$domain") \
    || { echo "auth-check: failed to build JSON payload (python3 missing?)" >&2; exit 1; }
fi

echo "auth-check: POST $endpoint as $user (platform=$plat, domain=$domain, TLS verify disabled)"
code=$(curl -k -sS -o /dev/null --max-time 15 -w '%{http_code}' \
       -H 'Content-Type: application/json' \
       -X POST "$endpoint" \
       --data-binary "$payload" 2>/dev/null || true)
[ -z "$code" ] && code=000

echo "auth-check: HTTP $code"
case "$code" in
  200|201)
    echo "auth-check: OK -- NDO accepted credentials."
    exit 0
    ;;
  400|401)
    echo "auth-check: BAD CREDENTIALS -- NDO rejected username/password." >&2
    echo "           Common causes: wrong password; bash history-expanded '!';" >&2
    echo "           trailing newline from copy-paste; wrong ndo_username/ndo_domain." >&2
    exit 1
    ;;
  403)
    echo "auth-check: FORBIDDEN -- account likely locked by repeated failures." >&2
    exit 1
    ;;
  000)
    echo "auth-check: NO RESPONSE -- $url unreachable / TLS failure / wrong host." >&2
    echo "           Test reachability:" >&2
    echo "             curl -k -sS -o /dev/null -w 'HTTP %{http_code}' $endpoint; echo" >&2
    exit 1
    ;;
  *)
    echo "auth-check: unexpected HTTP $code. Inspect NDO login response manually." >&2
    exit 1
    ;;
esac

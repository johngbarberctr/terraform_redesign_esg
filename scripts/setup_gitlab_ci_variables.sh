#!/usr/bin/env bash
# setup_gitlab_ci_variables.sh
#
# Idempotently provision CI/CD variables on the GitLab project that hosts
# this repository (default: root/terraform_redesign_esg on
# http://localhost:8080).
#
# Each variable's *value* is read from a same-named env var in your shell.
# The script never echoes values, only the variable name and its flags.
# Variables whose env var is unset are skipped, except VCENTER_DVS_VERSION
# which defaults to "unmanaged" if not set (the validator-friendly value
# for vCenter 7.x/8.x).
#
# Required env vars (script setup):
#   GITLAB_URL       default: http://localhost:8080
#   GITLAB_PROJECT   default: root/terraform_redesign_esg
#   GITLAB_TOKEN     Personal/project access token with 'api' scope (required)
#
# Mode selector (env var):
#   PROD=1           switch to PRODUCTION mode: provision only the 8 *_PROD
#                    APIC variables (apic-vmware-prod). NDO_*, VCENTER_*,
#                    and TF_HTTP_* are intentionally NOT touched, because:
#                      - the per-project CI files have no _PROD variant for
#                        NDO/TF_HTTP (one NDO is targeted at a time; switch
#                        by editing NDO_URL/NDO_PASSWORD values)
#                      - VCENTER_* is shared with lab unless you've added
#                        VCENTER_*_PROD variants to apic-vmware-prod/.gitlab-ci.yml
#                    Default (unset or 0) is LAB mode (the 18 lab variables).
#
# Optional env vars (variable values to push to GitLab):
#   LAB mode (PROD unset / 0):
#     NDO_USERNAME, NDO_PASSWORD, NDO_URL,
#     Site1_APIC_URL, Site1_APIC_USERNAME, Site1_APIC_PASSWORD, Site1_MCP_KEY,
#     Site2_APIC_URL, Site2_APIC_USERNAME, Site2_APIC_PASSWORD, Site2_MCP_KEY,
#     VCENTER_HOSTNAME_IP, VCENTER_DATACENTER, VCENTER_DVS_VERSION,
#     VCENTER_USERNAME, VCENTER_PASSWORD,
#     TF_HTTP_USERNAME, TF_HTTP_PASSWORD
#   PROD mode (PROD=1):
#     Site1_APIC_URL_PROD, Site1_APIC_USERNAME_PROD,
#     Site1_APIC_PASSWORD_PROD, Site1_MCP_KEY_PROD,
#     Site2_APIC_URL_PROD, Site2_APIC_USERNAME_PROD,
#     Site2_APIC_PASSWORD_PROD, Site2_MCP_KEY_PROD
#
# Usage:
#   export GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
#   export NDO_USERNAME=admin
#   export NDO_PASSWORD='C1sco12345'              # gets masked in GitLab
#   export NDO_URL='https://198.18.133.100'
#   export Site1_APIC_URL='https://198.18.134.252'
#   export Site1_APIC_USERNAME=admin
#   export Site1_APIC_PASSWORD='...'              # masked + protected
#   export Site1_MCP_KEY='...'                    # masked + protected, >=8 chars
#   ...
#   ./scripts/setup_gitlab_ci_variables.sh
#
# Re-run as many times as you need; each run is idempotent (POST -> PUT
# fallback). Only variables whose env var is set in *this* shell are
# created/updated.
#
# Security notes:
#   - This script contains no secrets. Do not paste secrets into it.
#   - GitLab masked/protected flags are set per spec:
#       masked          : NDO_PASSWORD, TF_HTTP_PASSWORD
#       masked+protected: Site1_APIC_PASSWORD, Site1_MCP_KEY,
#                         Site2_APIC_PASSWORD, Site2_MCP_KEY,
#                         VCENTER_PASSWORD
#       (no flags)      : everything else
#   - "Protected" means the variable is only injected into pipelines that
#     run on a protected branch/tag. Mark your deploy branch (e.g. main)
#     as Protected in GitLab > Settings > Repository > Protected branches.
#   - GitLab masking requires values to satisfy:
#       length >= 8, base64 alphabet only (A-Za-z0-9+/=@:._~-),
#       no whitespace, no newlines.
#     If a value violates this, GitLab returns 400 and the script reports
#     the error without leaking the value.

set -euo pipefail

GITLAB_URL="${GITLAB_URL:-http://localhost:8080}"
GITLAB_PROJECT="${GITLAB_PROJECT:-root/terraform_redesign_esg}"
: "${GITLAB_TOKEN:?GITLAB_TOKEN must be set (PAT with 'api' scope)}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "!! python3 is required for URL encoding" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "!! curl is required" >&2
  exit 1
fi

project_id_enc=$(printf '%s' "$GITLAB_PROJECT" | sed 's|/|%2F|g')
api="${GITLAB_URL%/}/api/v4/projects/${project_id_enc}/variables"

resp_file=$(mktemp)
trap 'rm -f "$resp_file"' EXIT

echo ">> GitLab : $GITLAB_URL"
echo ">> Project: $GITLAB_PROJECT"

# Up-front auth + project sanity check (hit /projects/<id>, not /variables, so
# the failure path doesn't create anything).
status=$(curl -sS -o "$resp_file" -w '%{http_code}' \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "${GITLAB_URL%/}/api/v4/projects/${project_id_enc}")
if [[ "$status" != "200" ]]; then
  echo "!! Project lookup failed: HTTP $status" >&2
  echo "   Body:" >&2
  cat "$resp_file" >&2 || true
  echo >&2
  echo "   Check GITLAB_URL, GITLAB_PROJECT, and that GITLAB_TOKEN has 'api' scope and Maintainer+ on the project." >&2
  exit 1
fi
echo ">> Auth OK"
echo

urlenc() {
  python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"
}

# is_gitlab_mask_compatible <value>
# Returns 0 (true) iff the value satisfies GitLab's masked-variable validator:
#   - single line (no CR/LF)
#   - length >= 8
#   - characters limited to Base64 alphabet (A-Za-z0-9+/=) plus @ : . ~ -
# Anything else (e.g. !, #, $, %, ^, &, *, (, ), spaces, etc.) makes the
# value un-maskable. The variable itself can still be stored without masking.
is_gitlab_mask_compatible() {
  local v="$1"
  [[ "${#v}" -ge 8 ]] || return 1
  case "$v" in
    *$'\n'*|*$'\r'*) return 1 ;;
  esac
  case "$v" in
    *[!A-Za-z0-9+/=@:.~-]*) return 1 ;;
  esac
  return 0
}

# set_var <NAME> <masked: true|false> <protected: true|false> [default-when-env-unset]
#
# Reads $NAME from the environment. If unset and no default given, skip.
# Always uses environment_scope=* (default) and variable_type=env_var.
#
# If masked=true was requested but the value contains characters outside
# GitLab's masking allow-list (e.g. !, #, $, %, ^, &, *, (, ), spaces),
# the request is automatically downgraded to masked=false with a clear
# warning. The 'protected' flag is preserved either way.
set_var() {
  local name="$1" masked="$2" protected="$3" default="${4-}"
  local value

  if [[ -n "${!name+x}" ]]; then
    value="${!name}"
  elif [[ -n "$default" ]]; then
    value="$default"
  else
    printf "   skip   %-26s (env var not set)\n" "$name"
    return 0
  fi

  # If the caller asked for masking but the value can't be masked, downgrade
  # rather than fail. This avoids a confusing GitLab '"value":["is invalid"]'
  # error when the only thing wrong is the alphabet (e.g. lab password ends
  # in '!').
  if [[ "$masked" == "true" ]] && ! is_gitlab_mask_compatible "$value"; then
    printf "   warn   %-26s value cannot be masked (chars outside [A-Za-z0-9+/=@:.~-] or len<8); setting masked=false; protected=%s preserved\n" "$name" "$protected" >&2
    masked=false
  fi

  local enc_name enc_value
  enc_name=$(urlenc "$name")
  enc_value=$(urlenc "$value")

  # Does it already exist?
  local exists_status
  exists_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "${api}/${enc_name}")

  local method url body verb
  if [[ "$exists_status" == "200" ]]; then
    method=PUT
    url="${api}/${enc_name}"
    body="value=${enc_value}&masked=${masked}&protected=${protected}&variable_type=env_var"
    verb=update
  else
    method=POST
    url="$api"
    body="key=${enc_name}&value=${enc_value}&masked=${masked}&protected=${protected}&variable_type=env_var"
    verb=create
  fi

  local status
  status=$(curl -sS -o "$resp_file" -w '%{http_code}' \
    -X "$method" -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    --data "$body" "$url")

  if { [[ "$method" == "POST" && "$status" == "201" ]] || \
       [[ "$method" == "PUT"  && "$status" == "200" ]]; }; then
    printf "   %-6s %-26s (masked=%s protected=%s)\n" "$verb" "$name" "$masked" "$protected"
  else
    echo "!! $name: $method returned HTTP $status" >&2
    sed 's/^/   /' "$resp_file" >&2 || true
    return 1
  fi
}

# --- Variables, in the order you listed them. ----------------------------------
if [[ "${PROD:-0}" == "1" ]]; then
  echo ">> PRODUCTION mode"
  echo "   Provisioning *_PROD APIC variables only (apic-vmware-prod root)."
  echo "   NDO_*, VCENTER_*, and TF_HTTP_* are intentionally NOT touched."
  echo "   See script header (PROD=1 section) for rationale."
  echo

  #             name                            masked  protected  default
  set_var       Site1_APIC_URL_PROD             false   false
  set_var       Site1_APIC_USERNAME_PROD        false   false
  set_var       Site1_APIC_PASSWORD_PROD        true    true
  set_var       Site1_MCP_KEY_PROD              true    true
  set_var       Site2_APIC_URL_PROD             false   false
  set_var       Site2_APIC_USERNAME_PROD        false   false
  set_var       Site2_APIC_PASSWORD_PROD        true    true
  set_var       Site2_MCP_KEY_PROD              true    true
else
  #             name                            masked  protected  default
  set_var       NDO_USERNAME                    false   false
  set_var       NDO_PASSWORD                    true    false
  set_var       NDO_URL                         false   false
  set_var       Site1_APIC_URL                  false   false
  set_var       Site1_APIC_USERNAME             false   false
  set_var       Site1_APIC_PASSWORD             true    true
  set_var       Site1_MCP_KEY                   true    true
  set_var       Site2_APIC_URL                  false   false
  set_var       Site2_APIC_USERNAME             false   false
  set_var       Site2_APIC_PASSWORD             true    true
  set_var       Site2_MCP_KEY                   true    true
  set_var       VCENTER_HOSTNAME_IP             false   false
  set_var       VCENTER_DATACENTER              false   false
  set_var       VCENTER_DVS_VERSION             false   false      unmanaged
  set_var       VCENTER_USERNAME                false   false
  set_var       VCENTER_PASSWORD                true    true
  set_var       TF_HTTP_USERNAME                false   false
  set_var       TF_HTTP_PASSWORD                true    false
fi

echo
echo ">> Done. Verify in GitLab > Settings > CI/CD > Variables."

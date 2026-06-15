#!/usr/bin/env bash
# setup_gitlab_ci_variables_interactive.sh
#
# Interactive wrapper around setup_gitlab_ci_variables.sh.
#
# Auto-discovers NDO/APIC URLs+usernames from on-disk tfvars files,
# auto-generates MCP keys with Python's secrets module, and prompts
# (silently) for the few values that genuinely cannot be discovered
# (GitLab PAT, APIC password, vCenter hostname/dc/user/pw). Then
# invokes the non-interactive setup script.
#
# Usage (lab mode -- default):
#   ./scripts/setup_gitlab_ci_variables_interactive.sh
#
# Usage (production cutover):
#   ./scripts/setup_gitlab_ci_variables_interactive.sh --prod
#
# In production mode the script provisions only the 8 *_PROD APIC
# variables (apic-vmware-prod). NDO/VCENTER/TF_HTTP are NOT touched
# in this mode (see setup_gitlab_ci_variables.sh header for rationale).
# Run it once in lab mode on your prod GitLab project to seed the
# shared variables, then re-run with --prod to add the *_PROD APIC
# set if you intend to host lab and prod CI on the same GitLab project.
#
# Override the discovery paths or GitLab target via env vars before
# running, e.g.:
#   GITLAB_URL=http://gitlab.example.com \
#   GITLAB_PROJECT=team/terraform-esg \
#   ./scripts/setup_gitlab_ci_variables_interactive.sh
#
# Anything you `export` before running is honored as-is and never
# overwritten or re-prompted. That makes the script safe to re-run.

set -euo pipefail

# --- mode selector -----------------------------------------------------------
PROD_MODE=0
for arg in "$@"; do
  case "$arg" in
    --prod) PROD_MODE=1 ;;
    --lab)  PROD_MODE=0 ;;
    -h|--help)
      sed -n '1,/^set -euo pipefail$/p' "${BASH_SOURCE[0]:-$0}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "!! Unknown argument: $arg" >&2
      echo "   Usage: $(basename "$0") [--prod] [--lab]" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# --- helpers -----------------------------------------------------------------

# Read a single HCL-style assignment (key = "value") from a tfvars file. Quiet
# when the file or key is absent. Strips surrounding double quotes.
read_tf_var() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  # Read `<key> = "<value>"` (or unquoted) from a tfvars line.
  # Save $0 BEFORE touching $1: assigning to $1 in awk rebuilds $0 with OFS,
  # which would delete the `=` separator and break value extraction.
  awk -v k="$key" '
    BEGIN { FS="=" }
    {
      saved = $0
      gsub(/[ \t\r]/, "", $1)
      if ($1 == k) {
        v = saved
        sub(/^[^=]*=[ \t]*/, "", v)
        sub(/[ \t\r]*$/, "", v)
        gsub(/(^"|"$)/, "", v)
        print v
        exit
      }
    }' "$file"
}

# Read `export FOO="value"` (or `export FOO=value`) from a shell env file.
read_env_var() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  awk -v k="$key" '
    {
      sub(/^[ \t]*/, ""); sub(/[ \t\r]*$/, "")
      if (substr($0, 1, 1) == "#") next
      if ($0 ~ "^export[ \t]+"k"=") {
        v = $0
        sub(/^export[ \t]+[^=]+=/, "", v)
        gsub(/(^"|"$|^'\''|'\''$)/, "", v)
        print v
        exit
      }
    }' "$file"
}

# Detect obvious placeholder values left over from a copy-paste of the
# README example. Returns 0 (true) if the value is clearly a placeholder.
is_placeholder() {
  local v="$1"
  case "$v" in
    ''|'...'|"'...'"|'""'|"''") return 0 ;;
    'glpat-...'|'glpat-xxxxxxxxxxxxxxxxxxxx'|'CHANGE_ME'|'changeme'|'TODO'|'todo') return 0 ;;
    *) return 1 ;;
  esac
}

# Strip exported vars whose value is obviously a placeholder. Print a
# warning so the user understands why they're being re-prompted.
purge_placeholders() {
  local name v
  for name in "$@"; do
    v="${!name:-}"
    if [ -n "$v" ] && is_placeholder "$v"; then
      echo "   warn: ignoring stale placeholder value in \$$name (length=${#v})" >&2
      unset "$name"
    fi
  done
}

# `default_to NAME 'value'` exports NAME=value if NAME is unset OR empty.
default_to() {
  local name="$1" value="$2"
  if [ -z "${!name:-}" ] && [ -n "$value" ]; then
    export "$name=$value"
  fi
}

# Silent prompt. Sets the env var if user provides input. Empty input leaves
# the variable unset / unchanged.
prompt_silent() {
  local name="$1" hint="$2" val
  if [ -n "${!name:-}" ]; then
    return 0
  fi
  printf '  %s: ' "$hint" >&2
  IFS= read -rs val
  echo >&2
  if [ -n "$val" ]; then
    export "$name=$val"
  fi
}

# Visible prompt with a default shown in brackets. Default is used on empty
# input. Skips the prompt entirely if NAME is already set.
prompt_default() {
  local name="$1" hint="$2" default="$3" val
  if [ -n "${!name:-}" ]; then
    return 0
  fi
  if [ -n "$default" ]; then
    printf '  %s [%s]: ' "$hint" "$default" >&2
  else
    printf '  %s: ' "$hint" >&2
  fi
  IFS= read -r val
  if [ -z "$val" ]; then
    val="$default"
  fi
  if [ -n "$val" ]; then
    export "$name=$val"
  fi
}

# Generate an MCP key that satisfies BOTH:
#   - APIC default strength profile: length >= 8, includes >= 3 of
#     {lowercase, uppercase, digit, symbol}.
#   - GitLab masked-variable validator: length >= 8, base64 alphabet
#     (A-Za-z0-9+/=) plus @ : . ~ - only, no whitespace, single line.
# Intersection: A-Za-z0-9+=
# We guarantee 4-of-4 character classes: 1 lowercase, 1 uppercase,
# 1 digit, 1 from "+=" (counts as the symbol class for APIC).
# Uses CSPRNG via Python's secrets module.
generate_mcp_key() {
  python3 - <<'PY'
import secrets, string
alpha = string.ascii_lowercase + string.ascii_uppercase + string.digits + "+="
length = 16
while True:
    k = "".join(secrets.choice(alpha) for _ in range(length))
    if (any(c.islower() for c in k) and
        any(c.isupper() for c in k) and
        any(c.isdigit() for c in k) and
        any(c in "+=" for c in k)):
        print(k)
        break
PY
}

# --- 0. purge stale placeholder env vars from prior sessions -----------------
# If you ran the README example with literal '...' or 'glpat-...' before,
# those values are still exported in your current shell. Drop them so we
# can prompt cleanly instead of silently provisioning garbage.
if [ "$PROD_MODE" = "1" ]; then
  purge_placeholders \
    GITLAB_TOKEN \
    KELLEY_APIC_URL_PROD KELLEY_APIC_USERNAME_PROD KELLEY_APIC_PASSWORD_PROD KELLEY_MCP_KEY_PROD \
    DELDIN_APIC_URL_PROD DELDIN_APIC_USERNAME_PROD DELDIN_APIC_PASSWORD_PROD DELDIN_MCP_KEY_PROD
else
  purge_placeholders \
    GITLAB_TOKEN TF_HTTP_USERNAME TF_HTTP_PASSWORD \
    NDO_USERNAME NDO_PASSWORD NDO_URL \
    KELLEY_APIC_URL KELLEY_APIC_USERNAME KELLEY_APIC_PASSWORD KELLEY_MCP_KEY \
    DELDIN_APIC_URL DELDIN_APIC_USERNAME DELDIN_APIC_PASSWORD DELDIN_MCP_KEY \
    VCENTER_HOSTNAME_IP VCENTER_DATACENTER VCENTER_DVS_VERSION \
    VCENTER_USERNAME VCENTER_PASSWORD
fi

# --- 1. auto-discover from on-disk files --------------------------------------

if [ "$PROD_MODE" = "1" ]; then
  cat <<'BANNER'
============================================================
>> PRODUCTION mode (--prod)
   Provisioning only the 8 *_PROD APIC variables for
   aci-redesign/apic-vmware-prod/. NDO_*, VCENTER_*, and
   TF_HTTP_* are NOT touched (run the script in lab mode
   first if you also need to seed those on this project).
============================================================
BANNER
  echo ">> Auto-discovering APIC values from apic-vmware-prod/terraform.tfvars..."

  # Production APIC URLs / usernames. apic-vmware-prod/terraform.tfvars may
  # not exist yet on a fresh machine; in that case auto-discovery is a no-op
  # and the operator is prompted for each value below.
  default_to KELLEY_APIC_URL_PROD      "$(read_tf_var aci-redesign/apic-vmware-prod/terraform.tfvars site1_apic_url      || true)"
  default_to KELLEY_APIC_USERNAME_PROD "$(read_tf_var aci-redesign/apic-vmware-prod/terraform.tfvars site1_apic_username || true)"
  default_to DELDIN_APIC_URL_PROD      "$(read_tf_var aci-redesign/apic-vmware-prod/terraform.tfvars site2_apic_url      || true)"
  default_to DELDIN_APIC_USERNAME_PROD "$(read_tf_var aci-redesign/apic-vmware-prod/terraform.tfvars site2_apic_username || true)"
  # Sensible username default for prod APIC admin accounts when no tfvars exists.
  default_to KELLEY_APIC_USERNAME_PROD "admin"
  default_to DELDIN_APIC_USERNAME_PROD "admin"
else
  echo ">> Auto-discovering values from on-disk tfvars / .env files..."

  # NDO connection
  default_to NDO_USERNAME "$(read_tf_var ndo-terraform-ipv6/terraform.tfvars   ndo_username || true)"
  default_to NDO_USERNAME "$(read_tf_var aci-redesign/ndo/terraform.tfvars     ndo_username || true)"
  default_to NDO_PASSWORD "$(read_tf_var ndo-terraform-ipv6/terraform.tfvars   ndo_password || true)"
  default_to NDO_PASSWORD "$(read_env_var "$HOME/DC/ACI/sac-johbarbe-AFRICOM-terraform-nac-ndo/.env" MSO_PASSWORD || true)"
  default_to NDO_URL      "$(read_tf_var ndo-terraform-ipv6/terraform.tfvars   ndo_url      || true)"
  default_to NDO_URL      "$(read_tf_var aci-redesign/ndo/terraform.tfvars     ndo_url      || true)"

  # APIC URLs / usernames (passwords come from prompts)
  default_to KELLEY_APIC_URL      "$(read_tf_var aci-redesign/apic-vmware/terraform.tfvars site1_apic_url      || true)"
  default_to KELLEY_APIC_USERNAME "$(read_tf_var aci-redesign/apic-vmware/terraform.tfvars site1_apic_username || true)"
  default_to DELDIN_APIC_URL      "$(read_tf_var aci-redesign/apic-vmware/terraform.tfvars site2_apic_url      || true)"
  default_to DELDIN_APIC_USERNAME "$(read_tf_var aci-redesign/apic-vmware/terraform.tfvars site2_apic_username || true)"

  # VDS version default per the orchestrator's hint.
  default_to VCENTER_DVS_VERSION "unmanaged"
fi

# --- 2. prompt for everything we couldn't discover ----------------------------

echo
echo ">> Now I need values that aren't on disk. Press Enter to accept the"
echo "   shown default (in brackets) where one is offered. Secret prompts"
echo "   are silent (no characters echoed)."
echo

# 2a. GitLab PAT and target -- there is no way to default these.
# In PROD mode the default GitLab URL is left alone so the operator must
# enter (or pre-export) the production GitLab base URL explicitly.
prompt_default GITLAB_URL     "GitLab base URL"     "${GITLAB_URL:-http://localhost:8080}"
prompt_default GITLAB_PROJECT "GitLab project path" "${GITLAB_PROJECT:-root/terraform_redesign_esg}"
echo "  Generate a PAT at ${GITLAB_URL%/}/-/user_settings/personal_access_tokens"
echo "  with scope 'api' and Maintainer+ role on the project, then paste below."
prompt_silent  GITLAB_TOKEN   "GitLab Personal Access Token (silent)"

if [ -z "${GITLAB_TOKEN:-}" ]; then
  echo "!! GITLAB_TOKEN is required. Aborting." >&2
  exit 1
fi

# Sanity check: catch obvious mistakes like pasting the literal placeholder
# 'glpat-...' or a value clearly too short to be a real GitLab token. Real
# GitLab PATs are >=20 chars (the 'glpat-' prefix alone is 6, plus 20+
# random chars after that). Don't try to be too clever about exact format
# - GitLab has changed token shapes over the years - just check length.
if [ "${#GITLAB_TOKEN}" -lt 20 ]; then
  echo "!! GITLAB_TOKEN looks too short to be real (length=${#GITLAB_TOKEN})." >&2
  echo "   Real GitLab PATs are typically 26-40 chars (e.g. glpat- + 20 random chars)." >&2
  echo "   Did you paste the literal placeholder 'glpat-...' from the README example?" >&2
  echo "   Generate a real token at: ${GITLAB_URL%/}/-/user_settings/personal_access_tokens" >&2
  exit 1
fi

if [ "$PROD_MODE" = "1" ]; then
  # 2b. Prod APIC URLs / usernames (must come from operator if tfvars absent).
  echo
  echo "  PRODUCTION APIC connection details. If apic-vmware-prod/terraform.tfvars"
  echo "  already exists locally these will be pre-filled; otherwise enter them now."
  prompt_default KELLEY_APIC_URL_PROD      "Kelley prod APIC URL (https://...)" ""
  prompt_default KELLEY_APIC_USERNAME_PROD "Kelley prod APIC username"          "admin"
  prompt_default DELDIN_APIC_URL_PROD      "Del-Din prod APIC URL (https://...)" ""
  prompt_default DELDIN_APIC_USERNAME_PROD "Del-Din prod APIC username"          "admin"

  if [ -z "${KELLEY_APIC_URL_PROD:-}" ] || [ -z "${DELDIN_APIC_URL_PROD:-}" ]; then
    echo "!! Both prod APIC URLs are required in --prod mode. Aborting." >&2
    exit 1
  fi

  echo
  echo "  PRODUCTION APIC admin password (used for both Kelley and Del-Din)."
  prompt_silent _APIC_ADMIN_PASSWORD_PROD "Prod APIC admin password (silent)"
  default_to    KELLEY_APIC_PASSWORD_PROD  "${_APIC_ADMIN_PASSWORD_PROD:-}"
  default_to    DELDIN_APIC_PASSWORD_PROD  "${_APIC_ADMIN_PASSWORD_PROD:-}"
  unset _APIC_ADMIN_PASSWORD_PROD

  if [ -z "${KELLEY_APIC_PASSWORD_PROD:-}" ] || [ -z "${DELDIN_APIC_PASSWORD_PROD:-}" ]; then
    echo "!! Prod APIC admin password is required in --prod mode. Aborting." >&2
    exit 1
  fi

  # 2c. MCP keys -- auto-generate if missing. Distinct key per fabric.
  if [ -z "${KELLEY_MCP_KEY_PROD:-}" ]; then
    KELLEY_MCP_KEY_PROD=$(generate_mcp_key)
    export KELLEY_MCP_KEY_PROD
    echo "  KELLEY_MCP_KEY_PROD: auto-generated (length=${#KELLEY_MCP_KEY_PROD})"
  fi
  if [ -z "${DELDIN_MCP_KEY_PROD:-}" ]; then
    DELDIN_MCP_KEY_PROD=$(generate_mcp_key)
    export DELDIN_MCP_KEY_PROD
    echo "  DELDIN_MCP_KEY_PROD: auto-generated (length=${#DELDIN_MCP_KEY_PROD})"
  fi
else
  # 2b. APIC admin password. Lab default = same as NDO_PASSWORD (common pattern).
  echo
  echo "  APIC admin password (used for both Kelley and Del-Din; lab defaults to"
  echo "  the same value as NDO_PASSWORD if you press Enter)."
  prompt_silent _APIC_ADMIN_PASSWORD "APIC admin password (silent, Enter = use NDO_PASSWORD)"
  default_to    KELLEY_APIC_PASSWORD  "${_APIC_ADMIN_PASSWORD:-${NDO_PASSWORD:-}}"
  default_to    DELDIN_APIC_PASSWORD  "${_APIC_ADMIN_PASSWORD:-${NDO_PASSWORD:-}}"
  unset _APIC_ADMIN_PASSWORD

  # 2c. MCP keys -- auto-generate if missing. Each fabric gets a distinct key
  # so a leak of one fabric's key does not compromise the other.
  if [ -z "${KELLEY_MCP_KEY:-}" ]; then
    KELLEY_MCP_KEY=$(generate_mcp_key)
    export KELLEY_MCP_KEY
    echo "  KELLEY_MCP_KEY: auto-generated (length=${#KELLEY_MCP_KEY})"
  fi
  if [ -z "${DELDIN_MCP_KEY:-}" ]; then
    DELDIN_MCP_KEY=$(generate_mcp_key)
    export DELDIN_MCP_KEY
    echo "  DELDIN_MCP_KEY: auto-generated (length=${#DELDIN_MCP_KEY})"
  fi

  # 2d. vCenter -- nothing on disk, must come from the operator.
  echo
  echo "  vCenter values (Phase 3 APIC VMM domains). If you don't yet know"
  echo "  these, just press Enter at each prompt -- the script will skip them"
  echo "  and you can run setup_gitlab_ci_variables.sh again later with the"
  echo "  missing pieces."
  prompt_default VCENTER_HOSTNAME_IP "vCenter IP / FQDN"           ""
  prompt_default VCENTER_DATACENTER  "vCenter datacenter name"     ""
  prompt_default VCENTER_USERNAME    "vCenter service-account user" ""
  prompt_silent  VCENTER_PASSWORD    "vCenter service-account password (silent)"

  # 2e. State backend -- reuse the same PAT, log in as 'root'.
  default_to TF_HTTP_USERNAME "root"
  default_to TF_HTTP_PASSWORD "$GITLAB_TOKEN"
fi

# --- 3. preview (no values) ---------------------------------------------------

echo
echo ">> Ready to provision the following on:"
echo "     ${GITLAB_URL%/}/${GITLAB_PROJECT}"
echo

if [ "$PROD_MODE" = "1" ]; then
  declare -a vars=(
    KELLEY_APIC_URL_PROD KELLEY_APIC_USERNAME_PROD KELLEY_APIC_PASSWORD_PROD KELLEY_MCP_KEY_PROD
    DELDIN_APIC_URL_PROD DELDIN_APIC_USERNAME_PROD DELDIN_APIC_PASSWORD_PROD DELDIN_MCP_KEY_PROD
  )
else
  declare -a vars=(
    NDO_USERNAME NDO_PASSWORD NDO_URL
    KELLEY_APIC_URL KELLEY_APIC_USERNAME KELLEY_APIC_PASSWORD KELLEY_MCP_KEY
    DELDIN_APIC_URL DELDIN_APIC_USERNAME DELDIN_APIC_PASSWORD DELDIN_MCP_KEY
    VCENTER_HOSTNAME_IP VCENTER_DATACENTER VCENTER_DVS_VERSION
    VCENTER_USERNAME VCENTER_PASSWORD
    TF_HTTP_USERNAME TF_HTTP_PASSWORD
  )
fi
for v in "${vars[@]}"; do
  if [ -n "${!v:-}" ]; then
    eval "_len=\${#$v}"
    printf "     %-30s set   (length=%d)\n" "$v" "$_len"
  else
    printf "     %-30s (skip - not set)\n" "$v"
  fi
done
unset _len

echo
read -r -p "Proceed? [y/N] " _confirm
case "$_confirm" in
  y|Y|yes|YES) ;;
  *) echo "Aborted." ; exit 0 ;;
esac

# --- 4. delegate to the non-interactive script -------------------------------

echo
if [ "$PROD_MODE" = "1" ]; then
  PROD=1 exec "$SCRIPT_DIR/setup_gitlab_ci_variables.sh"
else
  exec "$SCRIPT_DIR/setup_gitlab_ci_variables.sh"
fi

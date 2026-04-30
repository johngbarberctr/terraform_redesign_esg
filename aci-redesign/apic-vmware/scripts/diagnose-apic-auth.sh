#!/usr/bin/env bash
# diagnose-apic-auth.sh
#
# One-shot drill-down for the "Unable to authenticate" / auth-check HTTP 401
# case for one fabric. Runs three independent checks in your current shell:
#
#   A. Byte-level inspection of $TF_VAR_<fabric>_apic_password (length,
#      trailing whitespace/CR/LF, non-ASCII chars, '!' presence). Never
#      prints the plaintext password; only character-class fingerprints.
#
#   B. Re-posts the SAME env-var password to /api/aaaLogin.json (same code
#      path the ACI provider takes) and reports HTTP status.
#
#   C. Prompts you to re-type the password with `read -s`, then posts THAT
#      value. Compares the two HTTP results. If A fails but C succeeds, the
#      bug is in how the password was put into the env var (bash history
#      expansion, copy-paste artefacts, etc.).
#
# Usage:
#   ./diagnose-apic-auth.sh aedcg     # diagnose AEDCG (default)
#   ./diagnose-apic-auth.sh aedck     # diagnose AEDCK
#
# Output is safe to share -- the actual password is never echoed. Only the
# length, a character-class summary, and HTTP status codes are printed.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

FABRIC="${1:-aedcg}"
case "$FABRIC" in
  aedcg|aedck) ;;
  *)
    echo "diagnose: unknown fabric '$FABRIC'. Use one of: aedcg, aedck." >&2
    exit 2
    ;;
esac

PWVAR="TF_VAR_${FABRIC}_apic_password"
URLKEY="${FABRIC}_apic_url"
USERKEY="${FABRIC}_apic_username"

URL=$(awk -F '=' -v key="$URLKEY" '$0 ~ "^[[:space:]]*"key"[[:space:]]*=" {gsub(/[ "\r]/, "", $2); print $2; exit}' terraform.tfvars)
USER=$(awk -F '=' -v key="$USERKEY" '$0 ~ "^[[:space:]]*"key"[[:space:]]*=" {gsub(/[ "\r]/, "", $2); print $2; exit}' terraform.tfvars)

if [ -z "${URL:-}" ] || [ -z "${USER:-}" ]; then
  echo "diagnose ($FABRIC): could not read $URLKEY / $USERKEY from terraform.tfvars" >&2
  exit 1
fi

echo "=================================================================="
echo "APIC auth diagnostic ($FABRIC)"
echo "  tfvars $URLKEY  : $URL"
echo "  tfvars $USERKEY : $USER"
echo "  env var          : \$$PWVAR"
echo "=================================================================="

# ----- Check A: byte-level inspection of $PWVAR ---------------------------
echo
echo "[A] Inspecting \$$PWVAR (password never printed)"
echo "------------------------------------------------------------------"
if [ -z "${!PWVAR-}" ]; then
  echo "  $PWVAR is NOT SET in this shell."
  echo "  Export it (single quotes!) and re-run:"
  echo "    export $PWVAR='<APIC admin password>'"
  echo
  A_RESULT="unset"
else
  PWVAR="$PWVAR" python3 - <<'PY'
import os, unicodedata
pwvar = os.environ["PWVAR"]
p = os.environ[pwvar]
print(f"  length           : {len(p)}")
print(f"  leading space    : {p[:1].isspace() if p else False}")
print(f"  trailing space   : {p[-1:].isspace() if p else False}")
print(f"  trailing \\r      : {p.endswith(chr(13))}")
print(f"  trailing \\n      : {p.endswith(chr(10))}")
print(f"  contains '!'     : {'!' in p}")
print(f"  all-ascii        : {p.isascii()}")
if not p.isascii():
    for i, c in enumerate(p):
        if ord(c) > 127:
            name = unicodedata.name(c, "UNKNOWN")
            print(f"  non-ascii @ {i:>3}: U+{ord(c):04X} {name}")
classes = []
for c in p:
    if c.isdigit():        classes.append("D")
    elif c.isalpha():      classes.append("a" if c.islower() else "A")
    elif c.isspace():      classes.append(".")
    elif 0 <= ord(c) < 32: classes.append("c")
    else:                  classes.append("S")
print(f"  class fingerprint: {''.join(classes)}")
print(f"      (A=upper a=lower D=digit S=symbol .=space c=ctrl)")
PY
  A_RESULT="inspected"
fi

# ----- Helper: POST aaaLogin with a password from a named env var ---------
post_login() {
  # $1 = name of env var holding the password
  local var="$1"
  local payload
  payload=$(python3 -c 'import json,os,sys; print(json.dumps({"aaaUser":{"attributes":{"name":sys.argv[1],"pwd":os.environ[sys.argv[2]]}}}))' "$USER" "$var")
  local code
  code=$(curl -k -sS -o /dev/null --max-time 15 -w '%{http_code}' \
         -H 'Content-Type: application/json' \
         -X POST "$URL/api/aaaLogin.json" \
         --data-binary "$payload" 2>/dev/null || true)
  echo "${code:-000}"
}

# ----- Check B: POST using $PWVAR ------------------------------------------
echo
echo "[B] POST /api/aaaLogin.json using \$$PWVAR"
echo "------------------------------------------------------------------"
if [ "$A_RESULT" = "unset" ]; then
  echo "  skipped (env var not set)"
  B_CODE=""
else
  B_CODE=$(post_login "$PWVAR")
  echo "  HTTP $B_CODE"
fi

# ----- Check C: POST using interactively typed password --------------------
echo
echo "[C] Re-type the password at the prompt (input hidden)."
echo "    This proves whether it is your SHELL ENV that is wrong or APIC."
echo "------------------------------------------------------------------"
printf "    Password: "
IFS= read -r -s DIAGNOSE_TYPED_PW || true
echo
if [ -z "$DIAGNOSE_TYPED_PW" ]; then
  echo "  skipped (empty input)"
  C_CODE=""
else
  export DIAGNOSE_TYPED_PW
  C_CODE=$(post_login DIAGNOSE_TYPED_PW)
  echo "  HTTP $C_CODE"
  unset DIAGNOSE_TYPED_PW
fi

# ----- Verdict -------------------------------------------------------------
echo
echo "=================================================================="
echo "Verdict ($FABRIC)"
echo "=================================================================="
verdict() {
  local code="$1" label="$2"
  case "$code" in
    200) echo "  $label: OK (APIC accepted)" ;;
    401) echo "  $label: FAIL -- bad username/password" ;;
    403) echo "  $label: FAIL -- account locked (wait 5-10 min, or unlock)" ;;
    000) echo "  $label: FAIL -- no response from $URL" ;;
    "")  echo "  $label: skipped" ;;
    *)   echo "  $label: UNEXPECTED HTTP $code" ;;
  esac
}
verdict "$B_CODE" "[B] env-var password   "
verdict "$C_CODE" "[C] typed password     "

if [ "$B_CODE" = "200" ]; then
  echo
  echo "  >> auth is working now. Run: make plan"
elif [ "$C_CODE" = "200" ] && [ "$B_CODE" = "401" ]; then
  echo
  echo "  >> typed password works; env-var password does not."
  echo "     The bug is in how $PWVAR was exported."
  echo "     Re-export with SINGLE quotes to avoid bash history expansion:"
  echo "       export $PWVAR='<exact APIC admin password>'"
elif [ "$C_CODE" = "401" ]; then
  echo
  echo "  >> typed password also rejected. The password is genuinely wrong"
  echo "     on APIC, the account is disabled, or remote AAA is default."
  echo "     Next checks:"
  echo "       1. Log in to $URL GUI with the same password."
  echo "       2. If GUI rejects it, reset the admin password on APIC."
  echo "       3. If GUI works but REST does not, check AAA realm default;"
  echo "          try ${USERKEY} = 'apic:fallback\\\\admin' in tfvars."
elif [ "$C_CODE" = "403" ] || [ "$B_CODE" = "403" ]; then
  echo
  echo "  >> HTTP 403 -- admin account is locked out by repeated failures."
  echo "     Wait ~5-10 minutes, or unlock via another admin in the APIC GUI."
elif [ "$B_CODE" = "000" ] || [ "$C_CODE" = "000" ]; then
  echo
  echo "  >> no response from APIC. Check reachability:"
  echo "       curl -k -sS -o /dev/null -w 'HTTP %{http_code}\\n' $URL/api/aaaLogin.json"
fi

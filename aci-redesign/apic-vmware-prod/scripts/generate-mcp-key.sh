#!/usr/bin/env bash
# generate-mcp-key.sh
#
# Generate an APIC-compliant MCP (MisCabling Protocol) Instance Policy key
# and print an `export TF_VAR_<fabric>_mcp_key=...` line ready to eval.
#
# Each fabric has its own MCP key so a leak of one fabric's key does NOT
# compromise the other. Run the script twice in a fresh shell:
#
#   eval "$(./generate-mcp-key.sh aedcg)"      # sets TF_VAR_aedcg_mcp_key
#   eval "$(./generate-mcp-key.sh aedck)"      # sets TF_VAR_aedck_mcp_key
#
# APIC MCP password requirements (default strength profile):
#   - length >= 8 (we default to 16 for safety)
#   - characters from at least 3 of: lowercase, uppercase, digit, symbol
#   - must NOT be a dictionary word or contain the username
#   - must NOT contain spaces or APIC-reserved chars: \ " ' ` $
#
# Usage:
#   ./generate-mcp-key.sh aedcg            # default 16 chars
#   ./generate-mcp-key.sh aedck 20         # custom length (>=8)
#   eval "$(./generate-mcp-key.sh aedcg)"  # set in current shell
#
# The script does NOT write the key to disk. Capture it only in environment
# variables, CI masked variables, or a secrets manager.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <fabric> [length]" >&2
  echo "  fabric: aedcg | aedck" >&2
  echo "  length: integer >= 8 (default 16)" >&2
  exit 2
fi

FABRIC="$1"
case "$FABRIC" in
  aedcg|aedck) ;;
  *)
    echo "Error: unknown fabric '$FABRIC'. Use one of: aedcg, aedck." >&2
    exit 2
    ;;
esac

LEN="${2:-16}"

if ! [[ "$LEN" =~ ^[0-9]+$ ]] || (( LEN < 8 )); then
  echo "Error: length must be an integer >= 8 (got: $LEN)" >&2
  exit 2
fi

# Character classes. APIC-reserved chars excluded: \ " ' ` $ and whitespace.
# We also drop characters that commonly confuse shells in env-var export lines.
LOWER='abcdefghijklmnopqrstuvwxyz'
UPPER='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
DIGIT='0123456789'
SYMBOL='!@#%^&*()-_=+[]{};:,.?'

# Pick one character from a pool using a CSPRNG with rejection sampling to
# avoid modulo bias for pools that don't divide evenly into 256.
pick_one() {
  local pool="$1"
  local plen="${#pool}"
  local byte idx max
  max=$(( (256 / plen) * plen ))
  while :; do
    byte=$(LC_ALL=C od -An -N1 -tu1 /dev/urandom | tr -d ' \n')
    (( byte < max )) || continue
    idx=$(( byte % plen ))
    printf '%s' "${pool:idx:1}"
    return
  done
}

# First 4 chars: one from each class (ensures 4-of-4 compliance).
out=""
out+="$(pick_one "$LOWER")"
out+="$(pick_one "$UPPER")"
out+="$(pick_one "$DIGIT")"
out+="$(pick_one "$SYMBOL")"

# Remaining chars: from the full combined pool.
POOL="${LOWER}${UPPER}${DIGIT}${SYMBOL}"
remaining=$(( LEN - 4 ))
for _ in $(seq 1 "$remaining"); do
  out+="$(pick_one "$POOL")"
done

# Shuffle so the guaranteed class characters aren't always in positions 1-4.
# Use Perl's List::Util::shuffle (available by default on macOS and most
# Linux distros) to stay portable; `shuf` is GNU-only, `sort -R` varies.
shuffled="$(printf '%s' "$out" | perl -MList::Util=shuffle -e 'print join "", shuffle split //, <STDIN>')"

# Sanity: reject if the random output happens to contain a blocklisted token.
case "$shuffled" in
  *cisco*|*admin*|*password*|*CHANGE_ME*)
    echo "Error: generated value matched a blocklisted substring; re-run." >&2
    exit 3
    ;;
esac

# Emit an eval-able export line, fabric-specific. Single-quote to keep the
# shell honest even if the generator ever (shouldn't) produce a `!` in a
# history-expanding shell.
printf "export TF_VAR_%s_mcp_key='%s'\n" "$FABRIC" "$shuffled"

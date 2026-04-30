#!/usr/bin/env bash
# ci-secret-scan.sh
#
# Called from .gitlab-ci.yml validate-aci stage. Fails (exit 1) if it detects
# plaintext credentials or known-bad values in tracked files. Passes clean on
# repos where all secrets flow via Terraform variables / env vars / Vault.
#
# Allow-listed patterns (NOT flagged):
#   password: ""                       # empty
#   password: "CHANGE_ME"              # explicit placeholder
#   password: "${something}"           # Terraform template placeholder
#
# Flagged (exit 1):
#   password: "<any other literal>"    in aci-redesign/data/**/*.yaml|yml
#   username: "administrator|admin|root" in aci-redesign/data/**/*.yaml|yml
#   known-bad strings (e.g. the historical lab password) anywhere in the
#   tracked tree except docs/README/backups.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

LEAKS=0

fail() {
  echo "SECRET-SCAN ERROR: $*" >&2
  LEAKS=1
}

echo "== ci-secret-scan: known-bad strings in tracked files =="
# Use a pathspec that excludes docs and backups where the historical value
# may legitimately appear (e.g. in this rule file or rotation notes).
if git grep -nIE '(C1sco12345|password1[^a-zA-Z0-9]|admin123[^a-zA-Z0-9])' -- \
     ':!*.md' \
     ':!docs/**' \
     ':!backups/**' \
     ':!.gitlab/ci-secret-scan.sh' \
     2>/dev/null; then
  fail "known-bad credential string found above."
fi

echo "== ci-secret-scan: plaintext password in tracked NAC YAML =="
# Capture password: "<anything>" lines in tracked NAC YAML under data/.
# Allow empty and CHANGE_ME literals, and Terraform template placeholders.
PWD_HITS="$(mktemp)"
trap 'rm -f "$PWD_HITS"' EXIT
{
  git grep -nIE 'password:[[:space:]]*"[^"]+"' -- \
    'aci-redesign/data/**/*.yaml' \
    'aci-redesign/data/**/*.yml' \
    2>/dev/null || true
} | grep -vE '"(CHANGE_ME)?"' | grep -vE '"\$\{[^}]+\}"' >"$PWD_HITS" || true
if [ -s "$PWD_HITS" ]; then
  cat "$PWD_HITS" >&2
  fail "plaintext password literal(s) in tracked NAC YAML. Move to template + TF_VAR_*."
fi

echo "== ci-secret-scan: service-account username literal in tracked NAC YAML =="
if git grep -nIE 'username:[[:space:]]*"(administrator|admin|root)"' -- \
     'aci-redesign/data/**/*.yaml' \
     'aci-redesign/data/**/*.yml' \
     2>/dev/null; then
  fail "service-account username literal in tracked NAC YAML. Use template + TF_VAR_*."
fi

echo "== ci-secret-scan: tracked .tfvars (should always be empty set) =="
if git ls-files -- '*.tfvars' 2>/dev/null | grep -v '\.example$' | grep -q .; then
  git ls-files -- '*.tfvars' | grep -v '\.example$' >&2
  fail ".tfvars files are tracked (should be in .gitignore). Remove from git."
fi

if [ "$LEAKS" -ne 0 ]; then
  echo "ci-secret-scan: FAILED -- see errors above." >&2
  exit 1
fi

echo "ci-secret-scan: no obvious secret patterns found."

#!/usr/bin/env bash
# render-vmm-yaml.sh (apic-vmware-prod variant)
#
# Render templates/vmm-domain.nac.yaml.tftpl into
# ../data/nac-aci-<fabric>-prod-rendered/vmm-domain.nac.yaml BEFORE running
# `terraform plan`. The rendered file is gitignored.
#
# This is the production sister of ../../apic-vmware/scripts/render-vmm-yaml.sh.
# Functionally identical except it writes to the *-prod-rendered/ directories
# and is invoked from this prod root's Makefile / CI jobs. Keeping a copy
# (rather than symlinking) is intentional: the lab and prod render scripts
# can diverge later without surprises (different vCenter env-var sets,
# different output paths, different policy renames).
#
# Usage:
#   ./render-vmm-yaml.sh aedcg     # render AEDCG VMM YAML (production)
#   ./render-vmm-yaml.sh aedck     # render AEDCK VMM YAML (production)
#
# Required env vars (TF_VAR_* names):
#   TF_VAR_vcenter_hostname_ip
#   TF_VAR_vcenter_datacenter
#   TF_VAR_vcenter_username
#   TF_VAR_vcenter_password
#   TF_VAR_vcenter_dvs_version   # use "unmanaged" for vCenter 7.x / 8.x
#
# Output:
#   <module>/../data/nac-aci-<fabric>-prod-rendered/vmm-domain.nac.yaml (mode 0600)

set -euo pipefail

FABRIC="${1:-aedcg}"
case "$FABRIC" in
  aedcg) VMM_DOMAIN_NAME="APCG-VDS1" ;;
  aedck) VMM_DOMAIN_NAME="APCK-VDS1" ;;
  *)
    echo "render-vmm-yaml ($FABRIC): unknown fabric. Use one of: aedcg, aedck." >&2
    exit 2
    ;;
esac
# Each prod fabric adopts its own pre-existing per-site VDS in the production
# vCenter rather than creating a new shared one (Option A in the README).
export VMM_DOMAIN_NAME

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE="${MODULE_DIR}/templates/vmm-domain.nac.yaml.tftpl"
OUT_DIR="${MODULE_DIR}/../data/nac-aci-${FABRIC}-prod-rendered"
OUT_FILE="${OUT_DIR}/vmm-domain.nac.yaml"

missing=()
for v in \
  TF_VAR_vcenter_hostname_ip \
  TF_VAR_vcenter_datacenter \
  TF_VAR_vcenter_username \
  TF_VAR_vcenter_password \
  TF_VAR_vcenter_dvs_version
do
  if [ -z "${!v-}" ]; then
    missing+=("$v")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "render-vmm-yaml ($FABRIC): missing required env var(s):" >&2
  for v in "${missing[@]}"; do echo "  - $v" >&2; done
  echo >&2
  echo "Export them (see aci-redesign/README.md production cutover section)" >&2
  echo "before running this script." >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "render-vmm-yaml ($FABRIC): template not found at $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
chmod 0700 "$OUT_DIR"

python3 - "$TEMPLATE" "$OUT_FILE" <<'PY'
import os, sys, string, pathlib

tpl_path = pathlib.Path(sys.argv[1])
out_path = pathlib.Path(sys.argv[2])

mapping = {
    "vmm_domain_name":     os.environ["VMM_DOMAIN_NAME"],
    "vcenter_hostname_ip": os.environ["TF_VAR_vcenter_hostname_ip"],
    "vcenter_datacenter":  os.environ["TF_VAR_vcenter_datacenter"],
    "vcenter_username":    os.environ["TF_VAR_vcenter_username"],
    "vcenter_password":    os.environ["TF_VAR_vcenter_password"],
    "vcenter_dvs_version": os.environ["TF_VAR_vcenter_dvs_version"],
}

rendered = string.Template(tpl_path.read_text()).substitute(mapping)
out_path.write_text(rendered)
os.chmod(out_path, 0o600)
PY

echo "render-vmm-yaml ($FABRIC, prod): wrote $OUT_FILE (mode 0600)"

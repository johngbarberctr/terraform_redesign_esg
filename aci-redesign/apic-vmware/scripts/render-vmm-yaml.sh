#!/usr/bin/env bash
# render-vmm-yaml.sh
#
# Render templates/vmm-domain.nac.yaml.tftpl into
# ../data/nac-aci-<fabric>-rendered/vmm-domain.nac.yaml BEFORE running
# `terraform plan`. The rendered file is gitignored.
#
# Usage:
#   ./render-vmm-yaml.sh aedcg     # render AEDCG VMM YAML
#   ./render-vmm-yaml.sh aedck     # render AEDCK VMM YAML
#   ./render-vmm-yaml.sh           # default to aedcg (backward compatibility)
#
# Both fabrics currently consume the same TF_VAR_vcenter_* env vars (one
# vCenter shared between AEDCG and AEDCK in the lab and production today).
# If they diverge, introduce TF_VAR_<fabric>_vcenter_* and pick from those
# in the env-loading block below.
#
# Why this is a shell script and not a Terraform `local_file` resource:
# the `netascode/nac-aci/aci` module reads its YAML inputs at plan time. If
# we render via a `local_file` resource, the module has to depends_on that
# resource, which makes every module-internal `for_each`/`count` "known only
# after apply" and `terraform plan` fails. Rendering out-of-band keeps the
# file on disk as a plain static input.
#
# Required env vars (TF_VAR_* names):
#   TF_VAR_vcenter_hostname_ip
#   TF_VAR_vcenter_datacenter
#   TF_VAR_vcenter_username
#   TF_VAR_vcenter_password
#   TF_VAR_vcenter_dvs_version   # use "unmanaged" for vCenter 7.x / 8.x;
#                                # the pinned netascode/nac-aci module
#                                # validator rejects 7.0 / 8.0 / 8.0.2.
#
# Output:
#   <module>/../data/nac-aci-<fabric>-rendered/vmm-domain.nac.yaml (mode 0600)

set -euo pipefail

FABRIC="${1:-aedcg}"
case "$FABRIC" in
  aedcg) VMM_DOMAIN_NAME="APCG-VDS1" ;;
  aedck) VMM_DOMAIN_NAME="APCK-VDS1" ;;
  *)
    echo "render-vmm-yaml: unknown fabric '$FABRIC'. Use one of: aedcg, aedck." >&2
    exit 2
    ;;
esac
# VMM_DOMAIN_NAME is the VDS name in vCenter. Each fabric adopts its own
# pre-existing VDS rather than creating a shared one.
export VMM_DOMAIN_NAME

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE="${MODULE_DIR}/templates/vmm-domain.nac.yaml.tftpl"
OUT_DIR="${MODULE_DIR}/../data/nac-aci-${FABRIC}-rendered"
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
  echo "Export them (see aci-redesign/README.md sections 4-5) before running" >&2
  echo "this script." >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "render-vmm-yaml ($FABRIC): template not found at $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
chmod 0700 "$OUT_DIR"

# Use Python to substitute. string.Template understands `${var}` syntax,
# which matches the Terraform templatefile() syntax used in the template.
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

echo "render-vmm-yaml ($FABRIC): wrote $OUT_FILE (mode 0600)"

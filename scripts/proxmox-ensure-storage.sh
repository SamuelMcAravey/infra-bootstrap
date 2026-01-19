#!/usr/bin/env bash
set -euo pipefail

SNIPPETS_DIR_DEFAULT="/mnt/pve/shared-snippets"

usage() {
  cat <<'EOF'
Usage: proxmox-ensure-storage.sh [--snippets-dir <dir>]

Ensures a Proxmox snippets directory exists and contains:
  <snippets-dir>/cloud-init/
  <snippets-dir>/meta/

Defaults:
  --snippets-dir /mnt/pve/shared-snippets
EOF
}

main() {
  local snippets_dir="$SNIPPETS_DIR_DEFAULT"

  while (($#)); do
    case "$1" in
      --snippets-dir)
        snippets_dir="${2:-}"
        shift 2
        ;;
      --snippets-dir=*)
        snippets_dir="${1#*=}"
        shift 1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "ERROR: Unknown argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "$snippets_dir" ]]; then
    echo "ERROR: --snippets-dir is required." >&2
    exit 2
  fi

  mkdir -p "$snippets_dir/cloud-init" "$snippets_dir/meta"
  echo "OK: ensured $snippets_dir/{cloud-init,meta}"
}

main "$@"


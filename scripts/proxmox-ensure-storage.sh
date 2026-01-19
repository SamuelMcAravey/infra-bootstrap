#!/usr/bin/env bash
set -euo pipefail

SNIPPETS_DIR_DEFAULT="${SNIPPETS_DIR:-}"
if [[ -z "$SNIPPETS_DIR_DEFAULT" && -n "${SNIPPETS_STORAGE_ID:-}" ]]; then
  SNIPPETS_DIR_DEFAULT="/mnt/pve/${SNIPPETS_STORAGE_ID}/snippets"
fi

usage() {
  cat <<'EOF'
Usage: proxmox-ensure-storage.sh [--snippets-dir <dir>]

Ensures a Proxmox snippets directory exists.

Proxmox snippet files should be placed directly in the snippets directory (flat), for example:
  <snippets-dir>/ci-edgeapp.yaml
  <snippets-dir>/ci-edgeapp.version

Defaults:
  --snippets-dir $SNIPPETS_DIR (or /mnt/pve/$SNIPPETS_STORAGE_ID/snippets)
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
    echo "ERROR: --snippets-dir is required (or set SNIPPETS_DIR)." >&2
    exit 2
  fi

  mkdir -p "$snippets_dir"
  echo "OK: ensured $snippets_dir"
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-docker-host.sh <vmid> <name> [--template-id <id>] [--snippets-storage-id <id>] [options]
  create-docker-host.sh --vmid <id> --name <name> --template-id <id> --snippets-storage-id <id> [options]

Thin wrapper around scripts/proxmox-create-vm.sh with:
  --profile docker-host

Convenience:
  If <vmid> and <name> are provided positionally, the script reads defaults from env:
    TEMPLATE_ID=<template-vmid>
    SNIPPETS_STORAGE_ID=synology.lan
EOF
}

main() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  local create="$script_dir/proxmox-create-vm.sh"

  if [[ ! -f "$create" ]]; then
    echo "ERROR: missing $create" >&2
    exit 2
  fi

  if (($# == 0)); then
    usage
    exit 2
  fi

  if [[ "${1:-}" != -* ]] && [[ -n "${2:-}" ]] && [[ "${2:-}" != -* ]]; then
    local vmid="$1"
    local name="$2"
    shift 2

    local template_id="${TEMPLATE_ID:-}"
    local snippets_storage_id="${SNIPPETS_STORAGE_ID:-}"

    if [[ -z "$template_id" ]]; then
      echo "ERROR: TEMPLATE_ID is required (or pass --template-id)." >&2
      exit 2
    fi
    if [[ -z "$snippets_storage_id" ]]; then
      echo "ERROR: SNIPPETS_STORAGE_ID is required (or pass --snippets-storage-id)." >&2
      exit 2
    fi

    bash "$create" --profile docker-host \
      --vmid "$vmid" \
      --name "$name" \
      --template-id "$template_id" \
      --snippets-storage-id "$snippets_storage_id" \
      "$@"
    exit 0
  fi

  bash "$create" --profile docker-host "$@"
}

main "$@"

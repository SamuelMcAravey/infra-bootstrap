#!/usr/bin/env bash
set -euo pipefail

SNIPPETS_DIR_DEFAULT="/mnt/pve/shared-snippets"

usage() {
  cat <<'EOF'
Usage: proxmox-list-snippets.sh [--snippets-dir <dir>]

Lists cloud-init profiles available under:
  <snippets-dir>/cloud-init/*.yaml

Also shows the recorded version metadata if present:
  <snippets-dir>/meta/<profile>.version

Defaults:
  --snippets-dir /mnt/pve/shared-snippets
EOF
}

show_version_summary() {
  local version_path="$1"
  local ref=""
  local timestamp=""

  if [[ -f "$version_path" ]]; then
    ref="$(awk -F= '$1=="ref"{print $2}' "$version_path" 2>/dev/null || true)"
    timestamp="$(awk -F= '$1=="timestamp"{print $2}' "$version_path" 2>/dev/null || true)"
  fi

  if [[ -n "$ref" || -n "$timestamp" ]]; then
    printf "ref=%s ts=%s" "${ref:-?}" "${timestamp:-?}"
  else
    printf "no version recorded"
  fi
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

  local ci_dir="$snippets_dir/cloud-init"
  local meta_dir="$snippets_dir/meta"

  if [[ ! -d "$ci_dir" ]]; then
    echo "No cloud-init snippets found: $ci_dir does not exist"
    exit 0
  fi

  shopt -s nullglob
  local files=("$ci_dir"/*.yaml)
  shopt -u nullglob

  if ((${#files[@]} == 0)); then
    echo "No cloud-init snippets found in: $ci_dir"
    exit 0
  fi

  printf "%-24s  %-60s  %s\n" "profile" "path" "version"
  printf "%-24s  %-60s  %s\n" "------------------------" "------------------------------------------------------------" "-------------------------"

  local file
  for file in "${files[@]}"; do
    local profile
    profile="$(basename "$file" .yaml)"
    local version_path="$meta_dir/$profile.version"

    printf "%-24s  %-60s  %s\n" \
      "$profile" \
      "$file" \
      "$(show_version_summary "$version_path")"
  done
}

main "$@"


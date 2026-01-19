#!/usr/bin/env bash
set -euo pipefail

write_file_if_changed() {
  local path="$1"
  local content="$2"
  local mode="${3:-0644}"
  local owner="${4:-root:root}"

  local tmp
  tmp="$(mktemp)"
  printf '%s' "$content" > "$tmp"

  if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    return 0
  fi

  install -o "${owner%%:*}" -g "${owner##*:}" -m "$mode" "$tmp" "$path"
  rm -f "$tmp"
}

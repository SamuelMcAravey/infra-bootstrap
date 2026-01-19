#!/usr/bin/env bash
set -euo pipefail

retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local n=1
  while true; do
    if "$@"; then
      return 0
    fi

    if [[ "$n" -ge "$attempts" ]]; then
      return 1
    fi

    sleep "$delay"
    n=$((n + 1))
  done
}

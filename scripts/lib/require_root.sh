#!/usr/bin/env bash
set -euo pipefail

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: must run as root." >&2
    exit 10
  fi
}

#!/usr/bin/env bash
set -euo pipefail

APT_UPDATED=0

apt_install() {
  if [[ "$#" -eq 0 ]]; then
    return 0
  fi

  if [[ "$APT_UPDATED" -eq 0 ]]; then
    apt-get update -y
    APT_UPDATED=1
  fi

  apt-get install -y --no-install-recommends "$@"
}

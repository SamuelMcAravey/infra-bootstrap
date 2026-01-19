#!/usr/bin/env bash
set -euo pipefail

systemd_enable_start() {
  local unit="$1"
  systemctl daemon-reload
  systemctl enable "$unit"
  systemctl restart "$unit"
}

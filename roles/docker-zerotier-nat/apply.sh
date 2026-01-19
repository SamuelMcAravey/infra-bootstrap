#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/require_root.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/write_file_if_changed.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/systemd_enable_start.sh"

LOG_FILE="/var/log/bootstrap.log"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "$msg" | tee -a "$LOG_FILE"
}

install_script() {
  local src="$SCRIPT_DIR/docker-zerotier-nat.sh"
  local dst="/usr/local/sbin/docker-zerotier-nat.sh"
  local content

  content="$(cat "$src")"
  write_file_if_changed "$dst" "$content" 0755 root:root
}

install_unit() {
  local src="$SCRIPT_DIR/docker-zerotier-nat.service"
  local dst="/etc/systemd/system/docker-zerotier-nat.service"
  local content

  content="$(cat "$src")"
  write_file_if_changed "$dst" "$content" 0644 root:root
}

main() {
  require_root

  log "Role docker-zerotier-nat: start."
  install_script
  install_unit
  systemd_enable_start docker-zerotier-nat.service
  log "Role docker-zerotier-nat: complete."
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/require_root.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/apt_install.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/systemd_enable_start.sh"

LOG_FILE="/var/log/bootstrap.log"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "$msg" | tee -a "$LOG_FILE"
}

load_env() {
  if [[ -f /etc/bootstrap.env ]]; then
    # shellcheck disable=SC1091
    source /etc/bootstrap.env
  fi
}

check_tun_device() {
  if [[ -c /dev/net/tun ]]; then
    return 0
  fi

  log "ERROR: /dev/net/tun is missing. ZeroTier requires the TUN device."
  log "If this is a Proxmox LXC, add a bind mount for /dev/net/tun and allow cgroup device 10:200."
  log "Example: add to container config:"
  log "  lxc.cgroup2.devices.allow: c 10:200 rwm"
  log "  lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"
  log "ZeroTier can run in unprivileged containers, but missing TUN permissions will block it."
  return 1
}

install_zerotier() {
  log "Installing zerotier-one."
  apt_install zerotier-one
}

enable_service() {
  log "Enabling and starting zerotier-one."
  systemd_enable_start zerotier-one.service
}

join_network() {
  local net_id="${ZEROTIER_NETWORK_ID:-}"
  if [[ -z "$net_id" ]]; then
    log "ZEROTIER_NETWORK_ID not set; skipping join."
    return 0
  fi

  log "Joining ZeroTier network $net_id."
  if ! zerotier-cli join "$net_id" | tee -a "$LOG_FILE"; then
    log "ERROR: zerotier-cli join failed. Permissions may be blocked in this container."
    return 1
  fi
}

wait_for_interface() {
  local timeout=60
  local elapsed=0
  local iface=""

  while [[ "$elapsed" -lt "$timeout" ]]; do
    iface="$(ls /sys/class/net 2>/dev/null | awk '/^zt/ {print; exit 0}')"
    if [[ -n "$iface" ]]; then
      log "ZeroTier interface detected: $iface"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  log "WARNING: no zt* interface detected after ${timeout}s. Check permissions and network authorization."
  log "In LXC, ensure /dev/net/tun is available and cgroup device 10:200 is allowed."
  return 1
}

main() {
  require_root
  load_env

  log "Role zerotier: start."
  check_tun_device || true
  install_zerotier
  enable_service
  join_network || true
  wait_for_interface || true
  log "Role zerotier: complete."
}

main "$@"

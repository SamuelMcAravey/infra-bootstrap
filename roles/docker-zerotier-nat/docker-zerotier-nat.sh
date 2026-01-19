#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/bootstrap.log"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "$msg" | tee -a "$LOG_FILE"
}

detect_docker_subnet() {
  local subnet
  subnet="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}' 2>/dev/null || true)"
  if [[ -z "$subnet" ]]; then
    log "ERROR: unable to detect Docker bridge subnet."
    return 1
  fi
  echo "$subnet"
}

detect_zt_iface() {
  local iface
  iface="$(ip -o link show | awk -F': ' '/^\\d+: zt/ {print $2; exit}')"
  if [[ -z "$iface" ]]; then
    log "ERROR: no ZeroTier interface found (zt*)."
    return 1
  fi
  echo "$iface"
}

ensure_ip_forward() {
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
}

ensure_docker_user_chain() {
  if ! iptables -nL DOCKER-USER >/dev/null 2>&1; then
    iptables -N DOCKER-USER
  fi
}

ensure_rule() {
  local table="$1"
  shift
  if ! iptables -t "$table" -C "$@" >/dev/null 2>&1; then
    iptables -t "$table" -A "$@"
  fi
}

main() {
  local subnet zt_iface

  subnet="$(detect_docker_subnet)"
  zt_iface="$(detect_zt_iface)"

  log "Applying Docker -> ZeroTier NAT (subnet=$subnet, iface=$zt_iface)."

  ensure_ip_forward
  ensure_docker_user_chain

  ensure_rule nat POSTROUTING -s "$subnet" -o "$zt_iface" -j MASQUERADE
  ensure_rule filter DOCKER-USER -s "$subnet" -o "$zt_iface" -j ACCEPT
  ensure_rule filter DOCKER-USER -d "$subnet" -i "$zt_iface" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

  log "Docker -> ZeroTier NAT applied."
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/bootstrap.log"
APT_UPDATED=0

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

apt_update_once() {
  if [[ "$APT_UPDATED" -eq 0 ]]; then
    apt-get update -y
    APT_UPDATED=1
  fi
}

ensure_ansible() {
  apt_update_once
  apt-get install -y ansible
}

main() {
  load_env

  log "Ansible provisioning start."
  ensure_ansible

  PROFILE="${PROFILE:-edgeapp}"
  EDGE_NETWORK_NAME="${EDGE_NETWORK_NAME:-edge}"

  env PROFILE="$PROFILE" \
    REPO_URL="${REPO_URL:-}" \
    ZEROTIER_NETWORK_ID="${ZEROTIER_NETWORK_ID:-}" \
    CLOUDFLARE_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}" \
    APP_IMAGE="${APP_IMAGE:-}" \
    COMPOSE_PROJECT_DIR="${COMPOSE_PROJECT_DIR:-}" \
    EDGE_NETWORK_NAME="$EDGE_NETWORK_NAME" \
    ansible-playbook -i ansible/inventory/local.ini ansible/site.yml \
      --connection=local --become

  log "Ansible provisioning complete."
}

main "$@"

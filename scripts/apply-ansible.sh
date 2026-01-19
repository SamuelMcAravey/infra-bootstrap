#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/bootstrap.log"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "$msg" | tee -a "$LOG_FILE"
}

repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "$(cd "$script_dir/.." && pwd)"
}

load_env() {
  if [[ -f /etc/bootstrap.env ]]; then
    # shellcheck disable=SC1091
    source /etc/bootstrap.env
  fi

  if [[ -f /etc/bootstrap.secrets.env ]]; then
    # shellcheck disable=SC1091
    source /etc/bootstrap.secrets.env
  fi
}

main() {
  load_env

  PROFILE="${PROFILE:-edgeapp}"
  if [[ -z "$PROFILE" ]]; then
    log "ERROR: PROFILE is required."
    exit 2
  fi

  log "Ansible provisioning start (profile='$PROFILE')."

  local repo
  repo="$(repo_root)"
  if [[ ! -f "$repo/ansible/site.yml" ]]; then
    log "ERROR: ansible/site.yml not found under $repo."
    exit 2
  fi

  env PROFILE="$PROFILE" \
    REPO_URL="${REPO_URL:-}" \
    ZEROTIER_NETWORK_ID="${ZEROTIER_NETWORK_ID:-}" \
    CLOUDFLARE_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}" \
    APP_IMAGE="${APP_IMAGE:-}" \
    APP_PORT="${APP_PORT:-}" \
    APP_PORT_PUBLISH="${APP_PORT_PUBLISH:-}" \
    APP_CONTAINER_NAME="${APP_CONTAINER_NAME:-}" \
    COMPOSE_PROJECT_DIR="${COMPOSE_PROJECT_DIR:-}" \
    EDGE_NETWORK_NAME="${EDGE_NETWORK_NAME:-edge}" \
    ansible-playbook -i "$repo/ansible/inventory/local.ini" "$repo/ansible/site.yml" \
      --connection=local --become

  log "Ansible provisioning complete."
}

main "$@"

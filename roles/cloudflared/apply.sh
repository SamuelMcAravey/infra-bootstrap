#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/require_root.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/write_file_if_changed.sh"

LOG_FILE="/var/log/bootstrap.log"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "$msg" | tee -a "$LOG_FILE"
}

ensure_dirs() {
  mkdir -p /opt/cloudflared
}

install_compose_fragment() {
  local src="$REPO_ROOT/templates/docker-compose.cloudflared.yml"
  local dst="/opt/cloudflared/docker-compose.cloudflared.yml"
  local content

  content="$(cat "$src")"
  write_file_if_changed "$dst" "$content" 0644 root:root
}

write_env_file() {
  local dst="/opt/cloudflared/.env"
  local token="${CLOUDFLARE_TUNNEL_TOKEN:-}"

  if [[ -z "$token" ]]; then
    log "CLOUDFLARE_TUNNEL_TOKEN not set; compose will not start until provided."
  fi

  write_file_if_changed "$dst" "CLOUDFLARE_TUNNEL_TOKEN=${token}"$'\n' 0600 root:root
}

main() {
  require_root

  log "Role cloudflared: start."
  ensure_dirs
  install_compose_fragment
  write_env_file
  log "Cloudflared compose fragment written to /opt/cloudflared/docker-compose.cloudflared.yml"
  log "Start with: docker compose -f /opt/cloudflared/docker-compose.cloudflared.yml --env-file /opt/cloudflared/.env up -d"
  log "Role cloudflared: complete."
}

main "$@"

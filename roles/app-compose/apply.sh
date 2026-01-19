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

load_env() {
  if [[ -f /etc/bootstrap.env ]]; then
    # shellcheck disable=SC1091
    source /etc/bootstrap.env
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

write_compose_file() {
  local dir="$1"
  local content

  content="$(cat <<'EOF'
version: "3.8"

services:
  app1:
    image: ${APP_IMAGE}
    env_file:
      - .env
    ports:
      - "8080:8080"
    networks:
      - edge

networks:
  edge:
    external: true
EOF
)"

  write_file_if_changed "$dir/docker-compose.yml" "$content" 0644 root:root
}

write_env_file() {
  local dir="$1"
  local env_path="$dir/.env"
  local content

  if [[ -f "$env_path" ]]; then
    return 0
  fi

  content="$(cat <<'EOF'
# Add app-specific environment variables here.
# EXAMPLE_KEY=value
EOF
)"

  write_file_if_changed "$env_path" "$content" 0600 root:root
}

compose_up() {
  local dir="$1"
  local app_image="${APP_IMAGE:-}"

  if [[ -z "$app_image" ]]; then
    log "ERROR: APP_IMAGE is not set; cannot start compose stack."
    return 1
  fi

  log "Starting app compose stack in $dir."
  docker compose -f "$dir/docker-compose.yml" --env-file "$dir/.env" up -d
}

log_status() {
  local dir="$1"

  log "Compose status:"
  docker compose -f "$dir/docker-compose.yml" ps | tee -a "$LOG_FILE"

  if docker ps --format '{{.Names}}' | grep -q '^app1$'; then
    docker inspect app1 --format 'Health={{.State.Health.Status}} Status={{.State.Status}}' | tee -a "$LOG_FILE" || true
  fi
}

main() {
  require_root
  load_env

  local dir="${COMPOSE_PROJECT_DIR:-/srv/app}"

  log "Role app-compose: start (dir=$dir)."
  ensure_dir "$dir"
  write_compose_file "$dir"
  write_env_file "$dir"
  compose_up "$dir"
  log_status "$dir"
  log "Role app-compose: complete."
}

main "$@"

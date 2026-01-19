#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/require_root.sh"

LOG_FILE="/var/log/bootstrap.log"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "$msg" | tee -a "$LOG_FILE"
}

main() {
  require_root

  log "Role docker-network-edge: start."

  if docker network inspect edge >/dev/null 2>&1; then
    log "Docker network 'edge' already exists."
  else
    log "Creating docker network 'edge'."
    docker network create edge >/dev/null
  fi

  log "Role docker-network-edge: complete."
}

main "$@"

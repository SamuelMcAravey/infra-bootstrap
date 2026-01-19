#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/require_root.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/apt_install.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/write_file_if_changed.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/systemd_enable_start.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/retry.sh"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "$msg" | tee -a /var/log/bootstrap.log
}

main() {
  require_root

  local profile_name="$1"
  local profile_file="$REPO_ROOT/profiles/${profile_name}.sh"

  if [[ -z "$profile_name" ]]; then
    log "ERROR: profile name required."
    exit 2
  fi

  if [[ ! -f "$profile_file" ]]; then
    log "ERROR: profile file not found: $profile_file"
    exit 3
  fi

  log "Applying profile '$profile_name'."

  # shellcheck disable=SC1090
  source "$profile_file"

  if declare -F profile_steps >/dev/null; then
    profile_steps
  else
    log "ERROR: profile_steps not declared in $profile_file"
    exit 4
  fi

  log "Profile '$profile_name' applied."
}

main "$@"

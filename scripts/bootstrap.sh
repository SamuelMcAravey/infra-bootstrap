#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/bootstrap.log"
STATE_DIR="/var/lib/bootstrap"
PROFILE_DEFAULT="edgeapp"

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

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
}

should_run() {
  local current_profile="$1"
  local marker="$STATE_DIR/.last_profile"

  if [[ "${FORCE:-0}" == "1" ]]; then
    log "FORCE=1 set; running profile anyway."
    return 0
  fi

  if [[ ! -f "$marker" ]]; then
    log "No previous profile marker found; running profile."
    return 0
  fi

  local last_profile
  last_profile="$(cat "$marker")"
  if [[ "$last_profile" != "$current_profile" ]]; then
    log "Profile changed from '$last_profile' to '$current_profile'; running profile."
    return 0
  fi

  log "Profile '$current_profile' already applied; skipping."
  return 1
}

main() {
  load_env

  local profile
  profile="${PROFILE:-$PROFILE_DEFAULT}"

  log "Bootstrap starting (profile='$profile')."
  ensure_state_dir

  if should_run "$profile"; then
    /opt/bootstrap/repo/scripts/apply-profile.sh "$profile"
    echo "$profile" > "$STATE_DIR/.last_profile"
    log "Bootstrap completed for profile '$profile'."
  else
    log "Bootstrap exit: nothing to do."
  fi
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/bootstrap.log"
STATE_DIR="/var/lib/bootstrap"
PROFILE_DEFAULT="edgeapp"
BOOTSTRAP_ENV_PATH="/etc/bootstrap.env"
BOOTSTRAP_SECRETS_ENV_PATH="/etc/bootstrap.secrets.env"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "$msg" | tee -a "$LOG_FILE"
}

load_env() {
  if [[ -f "$BOOTSTRAP_ENV_PATH" ]]; then
    # shellcheck disable=SC1091
    source "$BOOTSTRAP_ENV_PATH"
  fi

  if [[ -f "$BOOTSTRAP_SECRETS_ENV_PATH" ]]; then
    # shellcheck disable=SC1091
    source "$BOOTSTRAP_SECRETS_ENV_PATH"
  fi
}

ensure_ansible() {
  if command -v ansible-playbook >/dev/null 2>&1; then
    log "Ansible already installed."
    return 0
  fi

  log "Installing Ansible."
  apt-get update -y
  apt-get install -y ansible
}

main() {
  load_env

  local profile
  profile="${PROFILE:-$PROFILE_DEFAULT}"

  log "Bootstrap starting (profile='$profile')."
  ensure_ansible

  log "Prompting for missing variables (if interactive)."
  bash /opt/bootstrap/repo/scripts/prompt-missing-vars.sh

  bash /opt/bootstrap/repo/scripts/apply-ansible.sh

  mkdir -p "$STATE_DIR"
  echo "$profile" > "$STATE_DIR/last_profile"
  log "Bootstrap completed for profile '$profile'."
}

main "$@"

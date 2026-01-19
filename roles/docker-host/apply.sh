#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/require_root.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/apt_install.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/write_file_if_changed.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/systemd_enable_start.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/retry.sh"

LOG_FILE="/var/log/bootstrap.log"

log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date -Is)" "$msg" | tee -a "$LOG_FILE"
}

ensure_docker_repo() {
  local keyring_dir="/etc/apt/keyrings"
  local keyring_path="/etc/apt/keyrings/docker.gpg"
  local repo_path="/etc/apt/sources.list.d/docker.list"
  local arch codename repo_line

  arch="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  repo_line="deb [arch=${arch} signed-by=${keyring_path}] https://download.docker.com/linux/debian ${codename} stable"

  mkdir -p "$keyring_dir"

  if [[ ! -f "$keyring_path" ]]; then
    log "Adding Docker GPG key."
    apt_install gnupg
    retry 3 2 curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o "$keyring_path"
    chmod 0644 "$keyring_path"
  fi

  write_file_if_changed "$repo_path" "${repo_line}"$'\n' 0644 root:root
}

install_docker() {
  log "Installing Docker Engine and plugins."
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

enable_docker() {
  log "Enabling and starting Docker."
  systemd_enable_start docker.service
}

add_user_to_docker() {
  local user="samuel"
  if id "$user" >/dev/null 2>&1; then
    log "Adding user '$user' to docker group."
    getent group docker >/dev/null 2>&1 || groupadd docker
    usermod -aG docker "$user"
  else
    log "User '$user' not found; skipping docker group membership."
  fi
}

print_versions() {
  if command -v docker >/dev/null 2>&1; then
    docker --version | tee -a "$LOG_FILE"
    docker compose version | tee -a "$LOG_FILE" || true
  fi
}

main() {
  require_root

  log "Role docker-host: start."
  ensure_docker_repo
  install_docker
  enable_docker
  add_user_to_docker
  print_versions
  log "Role docker-host: complete."
}

main "$@"

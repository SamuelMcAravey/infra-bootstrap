#!/usr/bin/env bash
set -euo pipefail

# Installs PowerShell (pwsh) on Debian-based Proxmox hosts.
# This script is intentionally standalone so you can run it once, then
# use the PowerShell orchestration scripts without the wrapper.

log() {
  printf '[%s] %s\n' "$(date -Is)" "$*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "ERROR: This script must be run as root (use sudo)."
    exit 2
  fi
}

detect_debian_like() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" == "debian" || "${ID_LIKE:-}" == *debian* ]]; then
      return 0
    fi
  fi
  return 1
}

install_pwsh_debian() {
  log "Installing PowerShell via Microsoft repo (Debian-based)."

  apt-get update -y
  apt-get install -y curl ca-certificates apt-transport-https gnupg

  local keyring="/etc/apt/keyrings/microsoft.gpg"
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o "$keyring"
  chmod 0644 "$keyring"

  local repo_file="/etc/apt/sources.list.d/microsoft-prod.list"
  local distro_codename="bookworm"
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ -n "${VERSION_CODENAME:-}" ]]; then
      distro_codename="$VERSION_CODENAME"
    fi
  fi

  echo "deb [arch=amd64 signed-by=${keyring}] https://packages.microsoft.com/debian/${distro_codename}/prod ${distro_codename} main" >"$repo_file"

  apt-get update -y
  apt-get install -y powershell
}

main() {
  require_root

  if command -v pwsh >/dev/null 2>&1; then
    log "pwsh already installed."
    exit 0
  fi

  if detect_debian_like; then
    install_pwsh_debian
  else
    log "ERROR: Unsupported OS. This installer only supports Debian-based Proxmox."
    exit 2
  fi

  if command -v pwsh >/dev/null 2>&1; then
    log "pwsh installed successfully."
    exit 0
  fi

  log "ERROR: pwsh installation failed."
  exit 2
}

main "$@"

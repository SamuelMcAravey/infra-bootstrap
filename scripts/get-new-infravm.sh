#!/usr/bin/env bash
set -euo pipefail

# Bootstrapper for running scripts/New-InfraVm.ps1 on any Proxmox host
# without requiring a local git clone. This script:
#   1) Ensures PowerShell (pwsh) is installed (Debian-based Proxmox)
#   2) Downloads the PowerShell script from GitHub raw
#   3) Executes pwsh and forwards all arguments

# Allow override: REF=branch-or-tag ./get-new-infravm.sh ...
REF="${REF:-main}"
RAW_BASE="https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap"
PS_SCRIPT_URL="${RAW_BASE}/${REF}/scripts/New-InfraVm.ps1"

log() {
  printf '[%s] %s\n' "$(date -Is)" "$*"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "ERROR: This script must be run as root (use sudo)."
    exit 2
  fi
}

install_pwsh() {
  # Install PowerShell on Debian-based Proxmox using Microsoft's repo.
  # Reference: https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
  log "PowerShell (pwsh) not found. Installing via Microsoft repository."

  apt-get update -y
  apt-get install -y curl ca-certificates apt-transport-https gnupg

  local keyring="/etc/apt/keyrings/microsoft.gpg"
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o "$keyring"
  chmod 0644 "$keyring"

  local repo_file="/etc/apt/sources.list.d/microsoft-prod.list"
  echo "deb [arch=amd64 signed-by=${keyring}] https://packages.microsoft.com/debian/12/prod bookworm main" >"$repo_file"

  apt-get update -y
  apt-get install -y powershell
}

download_ps_script() {
  local url="$1"
  local dest="$2"

  log "Downloading: $url"
  if ! curl -fsSL "$url" -o "$dest"; then
    log "ERROR: Failed to download PowerShell script from $url"
    exit 2
  fi
}

main() {
  require_root

  if ! command -v pwsh >/dev/null 2>&1; then
    install_pwsh
  fi

  local tmp_script
  tmp_script="$(mktemp /tmp/new-infravm.XXXXXX.ps1)"
  trap 'rm -f "$tmp_script"' EXIT

  download_ps_script "$PS_SCRIPT_URL" "$tmp_script"

  log "Running New-InfraVm.ps1 via pwsh (ref=${REF})"
  pwsh -NoProfile -File "$tmp_script" "$@"
}

main "$@"


#!/usr/bin/env bash
set -euo pipefail

# Installs PowerShell (pwsh) on Debian-based Proxmox hosts.
# Tested approach: Microsoft "debian/prod" repo + keyring in /etc/apt/keyrings.

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
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" == "debian" || "${ID_LIKE:-}" == *debian* ]]; then
      return 0
    fi
    # Proxmox often reports ID=debian but let's be explicit anyway.
    if [[ "${ID:-}" == "proxmox" || "${NAME:-}" == *Proxmox* ]]; then
      return 0
    fi
  fi
  return 1
}

# Proxmox can be "Debian-like" but may not have VERSION_CODENAME the way you expect.
# Prefer Debian codename mapping from /etc/debian_version when needed.
get_debian_codename() {
  # If VERSION_CODENAME exists, use it.
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ -n "${VERSION_CODENAME:-}" ]]; then
      echo "$VERSION_CODENAME"
      return 0
    fi
  fi

  # Fallback mapping from major version.
  if [[ -f /etc/debian_version ]]; then
    local dv major
    dv="$(cut -d'.' -f1 < /etc/debian_version || true)"
    major="${dv//[^0-9]/}"
    case "$major" in
      12) echo "bookworm" ;;
      11) echo "bullseye" ;;
      10) echo "buster" ;;
      9)  echo "stretch" ;;
      *)  echo "bookworm" ;; # safe default for modern Proxmox
    esac
    return 0
  fi

  # Last-resort default
  echo "bookworm"
}

install_pwsh_debian() {
  log "Installing PowerShell via Microsoft APT repo (Debian/Proxmox)."

  local arch codename keyring repo_file
  arch="$(dpkg --print-architecture)"
  codename="$(get_debian_codename)"

  # Dependencies
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg

  # Keyring
  keyring="/etc/apt/keyrings/microsoft.gpg"
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o "$keyring"
  chmod 0644 "$keyring"

  # Repo
  # Use the generic Debian "prod" repo; it's the most reliable for PowerShell on Debian-family.
  # We still include codename in the "suite" field so apt resolves correctly.
  repo_file="/etc/apt/sources.list.d/microsoft-prod.list"
  cat >"$repo_file" <<EOF
deb [arch=${arch} signed-by=${keyring}] https://packages.microsoft.com/repos/microsoft-debian-prod ${codename} main
EOF

  apt-get update -y
  apt-get install -y powershell

  # Verify
  if ! command -v pwsh >/dev/null 2>&1; then
    log "ERROR: pwsh not found after install."
    return 1
  fi
}

main() {
  require_root

  if command -v pwsh >/dev/null 2>&1; then
    log "pwsh already installed: $(pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || true)"
    exit 0
  fi

  if ! detect_debian_like; then
    log "ERROR: Unsupported OS. This installer only supports Debian-based Proxmox."
    exit 2
  fi

  install_pwsh_debian

  log "pwsh installed successfully."
  pwsh -NoLogo -NoProfile -Command '$PSVersionTable | Format-List' || true
}

main "$@"

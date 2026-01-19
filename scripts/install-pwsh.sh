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
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ -n "${VERSION_CODENAME:-}" ]]; then
      echo "$VERSION_CODENAME"
      return 0
    fi
  fi

  if [[ -f /etc/debian_version ]]; then
    local major
    major="$(cut -d'.' -f1 < /etc/debian_version | tr -cd '0-9')"
    case "$major" in
      13) echo "trixie" ;;
      12) echo "bookworm" ;;
      11) echo "bullseye" ;;
      10) echo "buster" ;;
      *)  echo "bookworm" ;;
    esac
    return 0
  fi

  echo "bookworm"
}

install_pwsh_debian() {
  log "Installing PowerShell via Microsoft repo (Debian/Proxmox)."

  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates curl gnupg

  local arch keyring repo_file os_codename ms_suite ms_path
  arch="$(dpkg --print-architecture)"
  os_codename="$(get_debian_codename)"

  # Microsoft repo suite fallback:
  # Debian 13 (trixie) isn't published yet in packages.microsoft.com for many products,
  # so use Debian 12 (bookworm) repo metadata.
  if [[ "$os_codename" == "trixie" ]]; then
    ms_suite="bookworm"
    ms_path="12"
  else
    ms_suite="$os_codename"
    case "$os_codename" in
      bookworm) ms_path="12" ;;
      bullseye) ms_path="11" ;;
      buster)   ms_path="10" ;;
      *)        ms_path="12" ;;
    esac
  fi

  keyring="/etc/apt/keyrings/microsoft.gpg"
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o "$keyring"
  chmod 0644 "$keyring"

  repo_file="/etc/apt/sources.list.d/microsoft-prod.list"
  cat >"$repo_file" <<EOF
deb [arch=${arch} signed-by=${keyring}] https://packages.microsoft.com/debian/${ms_path}/prod ${ms_suite} main
EOF

  apt-get update -y
  apt-get install -y powershell
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

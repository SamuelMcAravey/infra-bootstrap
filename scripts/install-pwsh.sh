#!/usr/bin/env bash
set -euo pipefail

# Install PowerShell on Debian-based systems (including Proxmox on Debian 13/Trixie)
# using the "universal package" (.tar.gz) from official GitHub releases.
#
# Source: Microsoft docs recommend tar.gz binary archive installs on Linux. :contentReference[oaicite:1]{index=1}

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "ERROR: Run as root (sudo)."
    exit 2
  fi
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_install_prereqs() {
  log "Installing prerequisites (curl, ca-certificates, tar, gzip)..."
  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates curl tar gzip
}

detect_arch() {
  # Map Debian arch -> PowerShell release arch tokens
  local arch
  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64) echo "x64" ;;
    arm64) echo "arm64" ;;
    armhf) echo "arm32" ;;
    *)
      log "ERROR: Unsupported architecture: $arch"
      exit 2
      ;;
  esac
}

get_latest_version() {
  # Follow redirect from /releases/latest -> .../tag/vX.Y.Z
  local url tag
  url="$(curl -fsSL -o /dev/null -w '%{url_effective}' -L \
    https://github.com/PowerShell/PowerShell/releases/latest)"
  tag="${url##*/}"          # v7.5.4
  tag="${tag#v}"            # 7.5.4
  if [[ ! "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log "ERROR: Could not determine latest PowerShell version from GitHub."
    exit 2
  fi
  echo "$tag"
}

verify_hash_if_available() {
  local ver="$1" asset="$2" file="$3"
  local hashes_url tmp_hashes expected actual

  hashes_url="https://github.com/PowerShell/PowerShell/releases/download/v${ver}/hashes.sha256"
  tmp_hashes="$(mktemp)"
  if curl -fsSL -o "$tmp_hashes" "$hashes_url"; then
    expected="$(grep -E "[[:space:]]\*?${asset}$" "$tmp_hashes" | awk '{print $1}' | head -n1 || true)"
    if [[ -z "$expected" ]]; then
      log "WARN: hashes.sha256 downloaded but no entry found for ${asset}. Skipping verification."
      rm -f "$tmp_hashes"
      return 0
    fi
    actual="$(sha256sum "$file" | awk '{print $1}')"
    rm -f "$tmp_hashes"
    if [[ "$actual" != "$expected" ]]; then
      log "ERROR: SHA256 mismatch for ${asset}"
      log "  expected: $expected"
      log "  actual:   $actual"
      exit 2
    fi
    log "SHA256 verified."
  else
    rm -f "$tmp_hashes"
    log "WARN: hashes.sha256 not available for v${ver}. Skipping verification."
  fi
}

install_pwsh_tarball() {
  local ver="$1"
  local ps_arch="$2"
  local asset="powershell-${ver}-linux-${ps_arch}.tar.gz"
  local url="https://github.com/PowerShell/PowerShell/releases/download/v${ver}/${asset}"

  local tmp tgz extract_dir install_root install_dir symlink
  tmp="$(mktemp -d)"
  tgz="${tmp}/${asset}"
  extract_dir="${tmp}/extract"

  install_root="/opt/microsoft/powershell"
  install_dir="${install_root}/7"
  symlink="/usr/local/bin/pwsh"

  log "Downloading PowerShell ${ver} (${ps_arch})..."
  curl -fL -o "$tgz" "$url"

  verify_hash_if_available "$ver" "$asset" "$tgz"

  log "Extracting..."
  mkdir -p "$extract_dir"
  tar -xzf "$tgz" -C "$extract_dir"

  log "Installing to ${install_dir}..."
  mkdir -p "$install_root"

  # Atomic-ish install: move aside existing, then replace.
  if [[ -d "$install_dir" ]]; then
    rm -rf "${install_dir}.old" || true
    mv "$install_dir" "${install_dir}.old"
  fi
  mv "$extract_dir" "$install_dir"
  chmod 0755 "$install_dir" || true

  log "Linking ${symlink} -> ${install_dir}/pwsh"
  ln -sf "${install_dir}/pwsh" "$symlink"

  rm -rf "$tmp"

  if ! need_cmd pwsh; then
    log "ERROR: pwsh not found after install."
    exit 2
  fi

  log "Installed: $(pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || true)"
}

usage() {
  cat <<EOF
Usage:
  sudo ./install-pwsh-universal.sh [--version X.Y.Z]

Options:
  --version X.Y.Z   Install a specific version (default: latest stable)
EOF
}

main() {
  require_root

  local version=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        version="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log "ERROR: Unknown argument: $1"
        usage
        exit 2
        ;;
    esac
  done

  if ! need_cmd apt-get; then
    log "ERROR: This script expects apt-get (Debian/Proxmox)."
    exit 2
  fi

  apt_install_prereqs

  local ps_arch ver
  ps_arch="$(detect_arch)"

  if [[ -n "$version" ]]; then
    ver="$version"
  else
    ver="$(get_latest_version)"
  fi

  # If already installed, skip if same version
  if need_cmd pwsh; then
    local current
    current="$(pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || true)"
    if [[ "$current" == "$ver" ]]; then
      log "pwsh already installed at version ${current}. Nothing to do."
      exit 0
    fi
    log "pwsh present (version: ${current}); will install ${ver}."
  fi

  install_pwsh_tarball "$ver" "$ps_arch"
}

main "$@"

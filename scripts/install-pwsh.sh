#!/usr/bin/env bash
set -euo pipefail

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "ERROR: Run as root (sudo)."
    exit 2
  fi
}

apt_install_prereqs() {
  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates curl tar gzip
}

detect_arch() {
  case "$(dpkg --print-architecture)" in
    amd64) echo "x64" ;;
    arm64) echo "arm64" ;;
    armhf) echo "arm32" ;;
    *) log "ERROR: Unsupported architecture"; exit 2 ;;
  esac
}

get_latest_version() {
  local url tag
  url="$(curl -fsSL -o /dev/null -w '%{url_effective}' -L \
    https://github.com/PowerShell/PowerShell/releases/latest)"
  tag="${url##*/}"; tag="${tag#v}"
  [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { log "ERROR: Can't detect latest version"; exit 2; }
  echo "$tag"
}

main() {
  require_root
  apt_install_prereqs

  local ver="${1:-$(get_latest_version)}"
  local arch; arch="$(detect_arch)"

  local asset="powershell-${ver}-linux-${arch}.tar.gz"
  local url="https://github.com/PowerShell/PowerShell/releases/download/v${ver}/${asset}"

  local tmp; tmp="$(mktemp -d)"
  local tgz="${tmp}/${asset}"
  local stage="${tmp}/stage"

  log "Downloading ${asset}..."
  curl -fL -o "$tgz" "$url"

  log "Extracting..."
  mkdir -p "$stage"
  tar -xzf "$tgz" -C "$stage"

  local root="/usr/local/powershell"
  local dir="${root}/7"
  local link="/usr/local/bin/pwsh"

  log "Installing to ${dir}..."
  mkdir -p "$root"
  rm -rf "${dir}.old" || true
  [[ -d "$dir" ]] && mv "$dir" "${dir}.old"
  mv "$stage" "$dir"

  # Force sane permissions: directories executable, pwsh executable
  chmod -R u+rwX,go+rX "$dir"
  chmod 0755 "$dir/pwsh"

  ln -sf "$dir/pwsh" "$link"
  rm -rf "$tmp"

  log "pwsh path: $(readlink -f "$link")"
  log "pwsh perms: $(ls -l "$(readlink -f "$link")")"

  pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
  log "Done."
}

main "$@"

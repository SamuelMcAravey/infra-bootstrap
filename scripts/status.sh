#!/usr/bin/env bash
set -euo pipefail

print_section() {
  local title="$1"
  printf '\n== %s ==\n' "$title"
}

print_section "cloud-init status"
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init status --long || true
else
  echo "cloud-init not installed."
fi

print_section "last applied profile"
if [[ -f /var/lib/bootstrap/last_profile ]]; then
  cat /var/lib/bootstrap/last_profile
else
  echo "No profile marker found."
fi

print_section "ansible version"
if command -v ansible >/dev/null 2>&1; then
  ansible --version | head -n 1 || true
else
  echo "ansible not installed."
fi

print_section "docker ps"
if command -v docker >/dev/null 2>&1; then
  docker ps || true
else
  echo "docker not installed."
fi

print_section "systemd status: docker-zerotier-nat.service"
if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-unit-files --type=service | awk '{print $1}' | grep -qx "docker-zerotier-nat.service"; then
    systemctl status --no-pager --lines=3 docker-zerotier-nat.service || true
  else
    echo "docker-zerotier-nat.service not installed."
  fi
else
  echo "systemctl not available."
fi

print_section "systemd status: app-compose.service"
if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-unit-files --type=service | awk '{print $1}' | grep -qx "app-compose.service"; then
    systemctl status --no-pager --lines=3 app-compose.service || true
  else
    echo "app-compose.service not installed."
  fi
else
  echo "systemctl not available."
fi

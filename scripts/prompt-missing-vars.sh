#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_ENV_PATH="/etc/bootstrap.env"
BOOTSTRAP_SECRETS_ENV_PATH="/etc/bootstrap.secrets.env"
PROFILE_DEFAULT="edgeapp"

log() {
  printf '[%s] %s\n' "$(date -Is)" "$*"
}

die() {
  log "ERROR: $*"
  exit 2
}

is_interactive() {
  [[ -t 0 ]]
}

ensure_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Must run as root to write ${BOOTSTRAP_ENV_PATH} and ${BOOTSTRAP_SECRETS_ENV_PATH}."
  fi
}

load_env_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    set +u
    # shellcheck disable=SC1090
    source "$path"
    set -u
  fi
}

is_secret_var() {
  local key="$1"
  case "$key" in
    CLOUDFLARE_TUNNEL_TOKEN) return 0 ;;
    *) return 1 ;;
  esac
}

required_vars_for_profile() {
  local profile="$1"
  case "$profile" in
    edgeapp)
      printf '%s\n' APP_IMAGE ZEROTIER_NETWORK_ID CLOUDFLARE_TUNNEL_TOKEN
      ;;
    app-only)
      printf '%s\n' APP_IMAGE
      ;;
    docker-host)
      : # none
      ;;
    *)
      # Unknown profile: no prompts. Ansible will handle validation.
      :
      ;;
  esac
}

example_for_key() {
  local key="$1"
  case "$key" in
    APP_IMAGE) echo "ghcr.io/example/app:latest" ;;
    ZEROTIER_NETWORK_ID) echo "ztxxxxxxxxxxxxxx" ;;
    CLOUDFLARE_TUNNEL_TOKEN) echo "token (will not echo)" ;;
    *) echo "value" ;;
  esac
}

validate_value() {
  local key="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    return 1
  fi

  if [[ "$value" =~ [[:space:]] ]]; then
    return 1
  fi

  case "$key" in
    APP_IMAGE)
      [[ "$value" =~ ^[A-Za-z0-9._/@:-]+$ ]]
      ;;
    ZEROTIER_NETWORK_ID)
      [[ "$value" =~ ^[A-Za-z0-9]+$ ]]
      ;;
    CLOUDFLARE_TUNNEL_TOKEN)
      [[ "$value" =~ ^[A-Za-z0-9._=-]+$ ]]
      ;;
    *)
      return 0
      ;;
  esac
}

ensure_file_perms() {
  local path="$1"
  local mode="$2"

  if [[ ! -f "$path" ]]; then
    umask 077
    : >"$path"
  fi

  chown root:root "$path"
  chmod "$mode" "$path"
}

upsert_kv() {
  local path="$1"
  local key="$2"
  local value="$3"

  local tmp
  tmp="$(mktemp)"

  local found=0
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
      printf '%s\n' "$line" >>"$tmp"
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*= ]]; then
      if [[ $found -eq 0 ]]; then
        printf '%s=%s\n' "$key" "$value" >>"$tmp"
        found=1
      fi
      continue
    fi

    printf '%s\n' "$line" >>"$tmp"
  done <"$path"

  if [[ $found -eq 0 ]]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi

  cat "$tmp" >"$path"
  rm -f "$tmp"
}

set_key() {
  local key="$1"
  local value="$2"

  if is_secret_var "$key"; then
    ensure_file_perms "$BOOTSTRAP_SECRETS_ENV_PATH" 0600
    upsert_kv "$BOOTSTRAP_SECRETS_ENV_PATH" "$key" "$value"
    log "Set ${key} in ${BOOTSTRAP_SECRETS_ENV_PATH}"
  else
    ensure_file_perms "$BOOTSTRAP_ENV_PATH" 0644
    upsert_kv "$BOOTSTRAP_ENV_PATH" "$key" "$value"
    log "Set ${key} in ${BOOTSTRAP_ENV_PATH}"
  fi
}

get_current_value() {
  local key="$1"
  # indirect expansion
  local current="${!key-}"
  printf '%s' "${current:-}"
}

prompt_for_key() {
  local key="$1"
  local example
  example="$(example_for_key "$key")"

  local value=""
  while true; do
    if is_secret_var "$key"; then
      printf "%s (%s): " "$key" "$example" >&2
      IFS= read -r -s value
      printf "\n" >&2
    else
      printf "%s (%s): " "$key" "$example" >&2
      IFS= read -r value
    fi

    if validate_value "$key" "$value"; then
      set_key "$key" "$value"
      return 0
    fi

    log "Invalid value for ${key}. No spaces; expected a simple token format."
  done
}

main() {
  ensure_root

  load_env_file "$BOOTSTRAP_ENV_PATH"
  load_env_file "$BOOTSTRAP_SECRETS_ENV_PATH"

  local profile="${PROFILE:-$PROFILE_DEFAULT}"
  profile="${profile//[[:space:]]/}"
  [[ -n "$profile" ]] || profile="$PROFILE_DEFAULT"

  mapfile -t required < <(required_vars_for_profile "$profile" || true)
  if ((${#required[@]} == 0)); then
    log "No required variable prompts for profile '${profile}'."
    return 0
  fi

  local -a missing=()
  local key
  for key in "${required[@]}"; do
    local current
    current="$(get_current_value "$key")"
    if [[ -z "$current" ]]; then
      missing+=("$key")
    fi
  done

  if ((${#missing[@]} == 0)); then
    log "All required variables are already set for profile '${profile}'."
    return 0
  fi

  if ! is_interactive; then
    die "Missing required variables for profile '${profile}': ${missing[*]}. Non-interactive run; set them in ${BOOTSTRAP_ENV_PATH} and/or ${BOOTSTRAP_SECRETS_ENV_PATH} and rerun."
  fi

  log "Prompting for missing required variables (profile='${profile}'): ${missing[*]}"
  for key in "${missing[@]}"; do
    prompt_for_key "$key"
  done
}

main "$@"


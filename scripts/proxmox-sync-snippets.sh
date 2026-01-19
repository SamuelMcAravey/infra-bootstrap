#!/usr/bin/env bash
set -euo pipefail

SNIPPETS_DIR_DEFAULT="/mnt/pve/shared-snippets"
REF_DEFAULT="main"

usage() {
  cat <<'EOF'
Usage: proxmox-sync-snippets.sh [options]

Fetches cloud-init profile YAML files from GitHub raw and writes them to a Proxmox snippets directory.

Options:
  --snippets-dir <dir>   Root directory containing cloud-init/ and meta/ (default: /mnt/pve/shared-snippets)
  --ref <ref>            Git ref/branch/tag/sha to fetch (default: main)
  --profiles <list>      Comma-separated profile names (default: all found in repo cloud-init/*.yaml)

Environment:
  REPO_RAW_BASE          Base raw URL (preferred), e.g.:
                         https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap

Example:
  REPO_RAW_BASE=https://raw.githubusercontent.com/your-org/infra-bootstrap \\
    ./scripts/proxmox-sync-snippets.sh --snippets-dir /var/lib/vz/snippets --ref main
EOF
}

log() {
  printf '[%s] %s\n' "$(date -Is)" "$*"
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

repo_root_from_script() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  (cd "$script_dir/.." && pwd)
}

derive_repo_raw_base_from_git() {
  local repo_root="$1"
  command -v git >/dev/null 2>&1 || return 1
  [[ -d "$repo_root/.git" ]] || return 1

  local origin
  origin="$(git -C "$repo_root" config --get remote.origin.url 2>/dev/null || true)"
  [[ -n "$origin" ]] || return 1

  local slug=""
  case "$origin" in
    git@github.com:*)
      slug="${origin#git@github.com:}"
      slug="${slug%.git}"
      ;;
    https://github.com/*)
      slug="${origin#https://github.com/}"
      slug="${slug%.git}"
      ;;
    http://github.com/*)
      slug="${origin#http://github.com/}"
      slug="${slug%.git}"
      ;;
    *)
      return 1
      ;;
  esac

  [[ -n "$slug" ]] || return 1
  printf 'https://raw.githubusercontent.com/%s' "$slug"
}

discover_profiles_from_repo() {
  local repo_root="$1"
  local ci_dir="$repo_root/cloud-init"
  [[ -d "$ci_dir" ]] || return 1

  shopt -s nullglob
  local files=("$ci_dir"/*.yaml)
  shopt -u nullglob

  ((${#files[@]} > 0)) || return 1

  local out=()
  local f
  for f in "${files[@]}"; do
    out+=("$(basename "$f" .yaml)")
  done

  printf '%s\n' "${out[@]}"
}

validate_cloud_config() {
  local path="$1"
  [[ -s "$path" ]] || return 1

  local first
  first="$(head -n 1 "$path" 2>/dev/null || true)"
  if [[ "$first" =~ ^#cloud-config ]]; then
    return 0
  fi

  grep -q 'cloud-config' "$path"
}

main() {
  local snippets_dir="$SNIPPETS_DIR_DEFAULT"
  local ref="$REF_DEFAULT"
  local profiles_csv=""

  while (($#)); do
    case "$1" in
      --snippets-dir)
        snippets_dir="${2:-}"
        shift 2
        ;;
      --snippets-dir=*)
        snippets_dir="${1#*=}"
        shift 1
        ;;
      --ref)
        ref="${2:-}"
        shift 2
        ;;
      --ref=*)
        ref="${1#*=}"
        shift 1
        ;;
      --profiles)
        profiles_csv="${2:-}"
        shift 2
        ;;
      --profiles=*)
        profiles_csv="${1#*=}"
        shift 1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  [[ -n "$snippets_dir" ]] || die "--snippets-dir is required"
  [[ -n "$ref" ]] || die "--ref is required"

  local repo_root
  repo_root="$(repo_root_from_script)"

  local repo_raw_base="${REPO_RAW_BASE:-}"
  if [[ -z "$repo_raw_base" ]]; then
    repo_raw_base="$(derive_repo_raw_base_from_git "$repo_root" || true)"
  fi
  [[ -n "$repo_raw_base" ]] || die "REPO_RAW_BASE must be set (or run from a git checkout with a GitHub origin remote)"

  local -a profiles=()
  if [[ -n "$profiles_csv" ]]; then
    local IFS=,
    read -r -a profiles <<<"$profiles_csv"
  else
    mapfile -t profiles < <(discover_profiles_from_repo "$repo_root") || true
  fi

  ((${#profiles[@]} > 0)) || die "No profiles selected (use --profiles edgeapp,app-only or run from a repo checkout that contains cloud-init/*.yaml)"

  local ensure_script="$repo_root/scripts/proxmox-ensure-storage.sh"
  if [[ -f "$ensure_script" ]]; then
    bash "$ensure_script" --snippets-dir "$snippets_dir" >/dev/null
  else
    mkdir -p "$snippets_dir/cloud-init" "$snippets_dir/meta"
  fi

  local ci_out_dir="$snippets_dir/cloud-init"
  local meta_out_dir="$snippets_dir/meta"

  local updated=0
  local unchanged=0
  local failed=0
  local -a updated_profiles=()
  local -a unchanged_profiles=()
  local -a failed_profiles=()

  local profile
  for profile in "${profiles[@]}"; do
    profile="${profile//[[:space:]]/}"
    [[ -n "$profile" ]] || continue

    local url="${repo_raw_base}/${ref}/cloud-init/${profile}.yaml"
    local tmp
    tmp="$(mktemp)"

    if ! curl -fsSL "$url" -o "$tmp"; then
      rm -f "$tmp"
      log "FAIL: $profile (download failed) $url"
      failed=$((failed + 1))
      failed_profiles+=("$profile")
      continue
    fi

    if ! validate_cloud_config "$tmp"; then
      rm -f "$tmp"
      log "FAIL: $profile (invalid cloud-config) $url"
      failed=$((failed + 1))
      failed_profiles+=("$profile")
      continue
    fi

    local dest="$ci_out_dir/${profile}.yaml"
    local changed="yes"
    if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
      changed="no"
    fi

    if [[ "$changed" == "yes" ]]; then
      mv "$tmp" "$dest"
      updated=$((updated + 1))
      updated_profiles+=("$profile")
      log "OK: updated $dest"
    else
      rm -f "$tmp"
      unchanged=$((unchanged + 1))
      unchanged_profiles+=("$profile")
      log "OK: unchanged $dest"
    fi

    local ts
    ts="$(date -Is)"
    cat >"$meta_out_dir/${profile}.version" <<EOF
ref=$ref
timestamp=$ts
url=$url
EOF
  done

  echo
  echo "Summary:"
  echo "  snippets_dir: $snippets_dir"
  echo "  repo_raw_base: $repo_raw_base"
  echo "  ref: $ref"
  echo "  updated: $updated"
  echo "  unchanged: $unchanged"
  echo "  failed: $failed"

  if ((${#updated_profiles[@]})); then
    printf '  updated_profiles: %s\n' "$(IFS=,; echo "${updated_profiles[*]}")"
  fi
  if ((${#unchanged_profiles[@]})); then
    printf '  unchanged_profiles: %s\n' "$(IFS=,; echo "${unchanged_profiles[*]}")"
  fi
  if ((${#failed_profiles[@]})); then
    printf '  failed_profiles: %s\n' "$(IFS=,; echo "${failed_profiles[*]}")"
  fi

  if ((failed > 0)); then
    exit 1
  fi
}

main "$@"

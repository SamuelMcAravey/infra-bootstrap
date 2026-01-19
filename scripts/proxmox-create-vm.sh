#!/usr/bin/env bash
set -euo pipefail

STORAGE_DEFAULT="local-zfs"
BRIDGE_DEFAULT="vmbr0"
CORES_DEFAULT="4"
MEMORY_DEFAULT="8192"
SNIPPETS_PATH_DEFAULT=""

usage() {
  cat <<'EOF'
Usage: proxmox-create-vm.sh --vmid <id> --name <name> --template-id <id> --profile <profile> --snippets-storage-id synology.lan [options]

Creates a Proxmox VM by cloning a cloud-init enabled template and attaching a profile-specific cloud-init snippet.

Required:
  --vmid <id>                 Target VMID to create
  --name <name>               VM name
  --template-id <id>          VMID of the template to clone
  --profile <profile>         Cloud-init profile name (matches cloud-init/<profile>.yaml)
  --snippets-storage-id <id>  Proxmox storage ID that provides snippets content (e.g. "shared-snippets")

Optional:
  --storage <id>              Target storage for the VM disks + cloudinit drive (default: local-zfs)
  --bridge <bridge>           Network bridge for net0 (default: vmbr0)
  --cores <n>                 vCPU cores (default: 4)
  --memory <mb>               Memory in MB (default: 8192)
  --disk-gb <n>               Resize primary disk to this size (best-effort)
  --snippets-path <path>      Path under the snippets root (default: cloud-init/<profile>.yaml)

Notes:
  - Sets cicustom to: user=synology.lan:snippets/<snippets-path>
  - If a version file exists at: synology.lan:snippets/meta/<profile>.version,
    the VM description is updated to include the profile + ref.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

normalize_snippets_path() {
  local p="$1"
  p="$(trim "$p")"
  p="${p#/}"
  if [[ "$p" == snippets/* ]]; then
    p="${p#snippets/}"
  fi
  printf '%s' "$p"
}

primary_disk_key_from_config() {
  local vmid="$1"
  local cfg
  cfg="$(qm config "$vmid" 2>/dev/null || true)"
  if echo "$cfg" | grep -qE '^scsi0:'; then
    echo "scsi0"
    return 0
  fi
  if echo "$cfg" | grep -qE '^virtio0:'; then
    echo "virtio0"
    return 0
  fi
  if echo "$cfg" | grep -qE '^sata0:'; then
    echo "sata0"
    return 0
  fi
  return 1
}

read_version_kv() {
  local version_path="$1"
  local key="$2"
  [[ -f "$version_path" ]] || return 1
  awk -F= -v k="$key" '$1==k{print $2; exit 0}' "$version_path" 2>/dev/null
}

main() {
  local vmid=""
  local name=""
  local template_id=""
  local storage="$STORAGE_DEFAULT"
  local bridge="$BRIDGE_DEFAULT"
  local cores="$CORES_DEFAULT"
  local memory="$MEMORY_DEFAULT"
  local disk_gb=""
  local profile=""
  local snippets_storage_id=""
  local snippets_path="$SNIPPETS_PATH_DEFAULT"

  while (($#)); do
    case "$1" in
      --vmid) vmid="${2:-}"; shift 2 ;;
      --vmid=*) vmid="${1#*=}"; shift 1 ;;
      --name) name="${2:-}"; shift 2 ;;
      --name=*) name="${1#*=}"; shift 1 ;;
      --template-id) template_id="${2:-}"; shift 2 ;;
      --template-id=*) template_id="${1#*=}"; shift 1 ;;
      --storage) storage="${2:-}"; shift 2 ;;
      --storage=*) storage="${1#*=}"; shift 1 ;;
      --bridge) bridge="${2:-}"; shift 2 ;;
      --bridge=*) bridge="${1#*=}"; shift 1 ;;
      --cores) cores="${2:-}"; shift 2 ;;
      --cores=*) cores="${1#*=}"; shift 1 ;;
      --memory) memory="${2:-}"; shift 2 ;;
      --memory=*) memory="${1#*=}"; shift 1 ;;
      --disk-gb) disk_gb="${2:-}"; shift 2 ;;
      --disk-gb=*) disk_gb="${1#*=}"; shift 1 ;;
      --profile) profile="${2:-}"; shift 2 ;;
      --profile=*) profile="${1#*=}"; shift 1 ;;
      --snippets-storage-id) snippets_storage_id="${2:-}"; shift 2 ;;
      --snippets-storage-id=*) snippets_storage_id="${1#*=}"; shift 1 ;;
      --snippets-path) snippets_path="${2:-}"; shift 2 ;;
      --snippets-path=*) snippets_path="${1#*=}"; shift 1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  vmid="$(trim "$vmid")"
  name="$(trim "$name")"
  template_id="$(trim "$template_id")"
  storage="$(trim "$storage")"
  bridge="$(trim "$bridge")"
  cores="$(trim "$cores")"
  memory="$(trim "$memory")"
  disk_gb="$(trim "$disk_gb")"
  profile="$(trim "$profile")"
  snippets_storage_id="$(trim "$snippets_storage_id")"
  snippets_path="$(trim "$snippets_path")"

  [[ -n "$vmid" ]] || die "--vmid is required"
  [[ -n "$name" ]] || die "--name is required"
  [[ -n "$template_id" ]] || die "--template-id is required"
  [[ -n "$profile" ]] || die "--profile is required"
  [[ -n "$snippets_storage_id" ]] || die "--snippets-storage-id is required"
  [[ -n "$storage" ]] || die "--storage is required"

  require_cmd qm
  require_cmd pvesm

  if qm status "$vmid" >/dev/null 2>&1; then
    die "VMID $vmid already exists"
  fi

  if [[ -z "$snippets_path" ]]; then
    snippets_path="cloud-init/${profile}.yaml"
  fi
  snippets_path="$(normalize_snippets_path "$snippets_path")"

  local ci_volume_id="${snippets_storage_id}:snippets/${snippets_path}"
  local ci_abs_path=""
  if ci_abs_path="$(pvesm path "$ci_volume_id" 2>/dev/null)"; then
    [[ -f "$ci_abs_path" ]] || die "Cloud-init snippet not found at resolved path: $ci_abs_path"
  else
    die "Unable to resolve snippet path via pvesm: $ci_volume_id (did you sync snippets and enable snippets content on that storage?)"
  fi

  echo "Cloning template $template_id -> VM $vmid ($name)"
  qm clone "$template_id" "$vmid" --name "$name" --full 1 --storage "$storage"

  echo "Configuring VM resources and cloud-init"
  qm set "$vmid" --cores "$cores" --memory "$memory"
  qm set "$vmid" --net0 "virtio,bridge=${bridge}"
  qm set "$vmid" --agent enabled=1
  qm set "$vmid" --ide2 "${storage}:cloudinit"

  echo "Attaching profile snippet (profile=$profile)"
  qm set "$vmid" --cicustom "user=${ci_volume_id}"

  if [[ -n "$disk_gb" ]]; then
    local disk_key=""
    disk_key="$(primary_disk_key_from_config "$vmid" || true)"
    if [[ -n "$disk_key" ]]; then
      echo "Resizing primary disk ($disk_key) to ${disk_gb}G (best-effort)"
      if ! qm resize "$vmid" "$disk_key" "${disk_gb}G"; then
        echo "WARN: disk resize failed; continuing" >&2
      fi
    else
      echo "WARN: unable to detect primary disk key; skipping resize" >&2
    fi
  fi

  local version_volume_id="${snippets_storage_id}:snippets/meta/${profile}.version"
  local version_abs_path=""
  if version_abs_path="$(pvesm path "$version_volume_id" 2>/dev/null)"; then
    if [[ -f "$version_abs_path" ]]; then
      local ref ts url
      ref="$(read_version_kv "$version_abs_path" "ref" || true)"
      ts="$(read_version_kv "$version_abs_path" "timestamp" || true)"
      url="$(read_version_kv "$version_abs_path" "url" || true)"

      local desc
      desc="infra-bootstrap profile=${profile}"
      [[ -n "$ref" ]] && desc="${desc} ref=${ref}"
      [[ -n "$ts" ]] && desc="${desc} synced_at=${ts}"
      [[ -n "$url" ]] && desc="${desc}"$'\n'"${url}"

      qm set "$vmid" --description "$desc" >/dev/null || true
    fi
  fi

  echo "Starting VM $vmid"
  qm start "$vmid"

  cat <<EOF

Next steps:
- Watch cloud-init logs on the VM:
  - /var/log/cloud-init.log
  - /var/log/cloud-init-output.log
- If provisioning did not run, confirm:
  - cicustom is set to: user=${ci_volume_id}
  - the snippet file exists at: ${ci_abs_path}
EOF
}

main "$@"

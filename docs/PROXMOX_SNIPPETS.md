# Proxmox Snippets on Shared Storage

This repo ships cloud-init user-data as profile-specific YAML files in `cloud-init/`. On Proxmox, you typically
store these YAML files as **snippets**, then attach them to VMs with `qm set ... --cicustom`.

This document explains how to configure a Proxmox storage to allow snippets and how to keep the snippets synced
from this GitHub repo.

## Enable Snippets Content Type

Proxmox only treats files as snippets if the storage has the `Snippets` content type enabled.

### Web UI (recommended)

1. Datacenter → Storage → select your storage (or add one).
2. Ensure the storage has `Snippets` enabled in **Content**.

### CLI (example)

Use `pvesm` to enable `snippets` on an existing storage:

```bash
pvesm set synology.lan --content snippets,iso,backup,vztmpl
```

Exact content types depend on your environment; the important part is `snippets`.

## Choose Where Snippets Live

On-disk, snippet files live under the storage's snippets directory:

- Local storage example: `/var/lib/vz/snippets/`
- Shared storage example: `/mnt/pve/synology.lan/snippets/`

The scripts in `scripts/` accept `--snippets-dir` which should point at that **snippets directory**.

## Sync Cloud-Init Profiles Into Snippets

This repo includes helper scripts intended to run on a Proxmox host:

- `scripts/proxmox-ensure-storage.sh`: create `cloud-init/` and `meta/` subfolders under `--snippets-dir`
- `scripts/proxmox-sync-snippets.sh`: download profile YAML files from GitHub raw into `--snippets-dir/cloud-init/`
- `scripts/proxmox-list-snippets.sh`: list what is installed and show recorded version info

### One-time setup

Pick the snippets directory for your storage (examples):

```bash
# SNIPPETS_DIR=/var/lib/vz/snippets
SNIPPETS_DIR=/mnt/pve/synology.lan/snippets
```

Then initialize the folders:

```bash
bash ./scripts/proxmox-ensure-storage.sh --snippets-dir "$SNIPPETS_DIR"
```

### Sync from GitHub raw

Set `REPO_RAW_BASE` to your GitHub raw base URL (no secrets required):

```bash
REPO_RAW_BASE=https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap
bash ./scripts/proxmox-sync-snippets.sh --snippets-dir "$SNIPPETS_DIR" --ref main
```

This writes:

- `"$SNIPPETS_DIR/cloud-init/<profile>.yaml"`
- `"$SNIPPETS_DIR/meta/<profile>.version"` (records `ref` + `timestamp` + `url`)

To sync a subset of profiles:

```bash
bash ./scripts/proxmox-sync-snippets.sh --snippets-dir "$SNIPPETS_DIR" --profiles edgeapp,app-only
```

### List installed snippets

```bash
bash ./scripts/proxmox-list-snippets.sh --snippets-dir "$SNIPPETS_DIR"
```

## Using Snippets With VMs

Once the YAML is present in the snippets directory, attach it to a VM (example):

```bash
qm set <vmid> --cicustom "user=synology.lan:snippets/cloud-init/edgeapp.yaml"
```

The path after `snippets/` should match what was written by the sync script.

For a repeatable VM creation flow (clone template + attach profile snippet + start VM), see `docs/PROXMOX_VM_CREATE.md`.

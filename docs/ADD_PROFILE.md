# Add A New Profile

Minimal, operational steps to add a new profile end-to-end.

## 1) Create The Ansible Profile File

Create `ansible/profiles/<name>.yml` and set `profile_roles`:

```yaml
---
- name: Set profile roles
  ansible.builtin.set_fact:
    profile_roles:
      - <role_1>
      - <role_2>
```

The profile is loaded by `ansible/site.yml` via `profiles/{{ profile }}.yml`.

## 2) Create The Cloud-Init Profile YAML

Create `cloud-init/<name>.yaml` and set:

- `PROFILE=<name>` in `/etc/bootstrap.env`

You can copy an existing file (for example `cloud-init/edgeapp.yaml`) and edit only the profile + env placeholders.

## 3) (Optional) Add A Wrapper VM Creation Script

Create `scripts/create-<name>.sh` that forwards to `scripts/proxmox-create-vm.sh`:

```bash
bash ./scripts/proxmox-create-vm.sh --profile <name> "$@"
```

## 4) Sync Snippets On The Proxmox Host

```bash
SNIPPETS_DIR=/mnt/pve/synology.lan/snippets
REPO_RAW_BASE=https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap
bash ./scripts/proxmox-sync-snippets.sh --snippets-dir "$SNIPPETS_DIR" --ref main
```

## 5) Create A VM With The New Profile

```bash
bash ./scripts/proxmox-create-vm.sh \
  --vmid <vmid> \
  --name <name> \
  --template-id <template-vmid> \
  --snippets-storage-id synology.lan \
  --profile <name>
```


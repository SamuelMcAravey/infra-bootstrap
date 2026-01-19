# Repeatable Proxmox VM Creation

This repo includes Proxmox host-side scripts to create VMs from a cloud-init enabled template and attach a
profile-specific `cloud-init/*.yaml` snippet.

## Assumptions

- Your template VM has cloud-init enabled (and is marked as a template).
- Your target storage supports `cloudinit` volumes (for the `ide2: <storage>:cloudinit` drive).
- Your snippets storage ID exists in Proxmox and has `Snippets` enabled (see `docs/PROXMOX_SNIPPETS.md`).
- The profile snippet has been synced into the snippets storage as `ci-<profile>.yaml` (flat in the snippets root).

## Generic Script

Run on a Proxmox host:

```bash
bash ./scripts/proxmox-create-vm.sh \
  --vmid 1201 \
  --name edgeapp-01 \
  --template-id 9000 \
  --snippets-storage-id shared-snippets \
  --profile edgeapp
```

If you used `scripts/proxmox-sync-snippets.sh`, the VM description will include the profile + ref when a version
file exists at `ci-<profile>.version`.

## Profile Wrappers

These call the generic script with `--profile` pre-selected:

```bash
bash ./scripts/create-edgeapp.sh --vmid 1201 --name edgeapp-01 --template-id 9000 --snippets-storage-id shared-snippets
bash ./scripts/create-app-only.sh --vmid 1202 --name app-01    --template-id 9000 --snippets-storage-id shared-snippets
bash ./scripts/create-docker-host.sh --vmid 1203 --name dock-01 --template-id 9000 --snippets-storage-id shared-snippets
```

## After Boot

On the VM, check:

- `/var/log/cloud-init.log`
- `/var/log/cloud-init-output.log`

# Proxmox Cloud-Init Workflow

## Snippets Location

Store cloud-init user-data snippets on the Proxmox host at:

- Local storage: `/var/lib/vz/snippets/`
- Shared storage: `/mnt/pve/<storage-id>/snippets/` (flat files; recommended)

## Attach Profile Snippet

This repo syncs profile snippets to Proxmox as flat files named `ci-<profile>.yaml` (see `docs/PROXMOX_SNIPPETS.md`).

Attach the snippet as **vendor-data** so Proxmox can keep managing user/SSH keys via its generated user-data:

```bash
qm set <vmid> --cicustom "vendor=<storage-id>:snippets/ci-edgeapp.yaml"
```

Cloud-init inside the VM must be installed/enabled for any of this to run.

## Safe Iteration

1. Clone the VM (or clone the template to a new VM).
2. Update the snippet file in `/var/lib/vz/snippets`.
3. Reboot the VM.
4. Check cloud-init logs to confirm the run:

   - `/var/log/cloud-init.log`
   - `/var/log/cloud-init-output.log`

Repeat on a clone to avoid breaking your base template.

## Shared Snippets

For storing cloud-init user-data snippets on shared storage and syncing them from GitHub, see `docs/PROXMOX_SNIPPETS.md`.

## VM Creation

For repeatable VM creation from a template while attaching a profile snippet, see `docs/PROXMOX_VM_CREATE.md`.

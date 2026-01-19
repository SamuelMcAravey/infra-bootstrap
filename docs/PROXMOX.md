# Proxmox Cloud-Init Workflow

## Snippets Location

Store cloud-init user-data snippets on the Proxmox host at:

`/var/lib/vz/snippets`

## Attach User-Data

Pick the cloud-init user-data file matching your desired profile (for example `cloud-init/edgeapp.yaml`) and set
`REPO_URL` (plus any required vars like `APP_IMAGE` or `CLOUDFLARE_TUNNEL_TOKEN`) before uploading it.

Upload the user-data file from `cloud-init/` into the snippets folder, then attach it to the VM:

```bash
qm set <vmid> --cicustom "user=local:snippets/<file>"
```

This tells Proxmox to use your custom `user-data` for cloud-init.

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

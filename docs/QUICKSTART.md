# Quickstart (Proxmox Host Admin)

Assumes:
- Snippets storage exists and is mounted at `/mnt/pve/synology.lan/snippets` (flat).
- A Debian template VM exists with cloud-init enabled (`TemplateId`).

## 1) Create An `edgeapp` VM (single entrypoint)

Option A: run the wrapper (no local clone required):

```bash
sudo bash https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap/main/scripts/get-new-infravm.sh \
  -Profile edgeapp -VmId 1201 -Name edgeapp-01 -TemplateId 9000
```

Option B: run PowerShell directly (if you already have the repo):

```bash
sudo pwsh ./scripts/New-InfraVm.ps1 -Profile edgeapp -VmId 1201 -Name edgeapp-01 -TemplateId 9000
```

The script will prompt for missing inputs (secrets are hidden):

```
APP_IMAGE: ghcr.io/example/app:latest
ZEROTIER_NETWORK_ID: ztabcdef12345678
CLOUDFLARE_TUNNEL_TOKEN (secret): ********
```

Generated snippets are written to:

```
/mnt/pve/synology.lan/snippets/ci-<profile>-<vmid>.yaml
```

## 2) Verify On The Guest

```bash
cloud-init status --long
sudo tail -n 200 /var/log/cloud-init-output.log
sudo tail -n 200 /var/log/bootstrap.log
```

For details/troubleshooting:
- `docs/WALKTHROUGH_PROXMOX.md`
- `docs/PROXMOX_SNIPPETS.md`
- `docs/PROXMOX_VM_CREATE.md`

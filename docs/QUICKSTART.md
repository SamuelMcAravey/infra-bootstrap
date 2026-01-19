# Quickstart (Proxmox Host Admin)

Assumes:
- A cloud-init enabled template VM already exists.
- A Proxmox storage ID for snippets already exists and has snippet files synced to it.

## 1) Sync Cloud-Init Snippets (main)

```bash
sudo mkdir /opt/infra-bootstrap
cd /opt/infra-bootstrap
REPO_RAW_BASE=https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap \
bash ./scripts/proxmox-sync-snippets.sh --snippets-dir /mnt/pve/synology.lan/snippets --ref main
```

## 2) Create An `edgeapp` VM

```bash
cd /opt/infra-bootstrap
TEMPLATE_ID=<template-vmid> SNIPPETS_STORAGE_ID=synology.lan \
bash ./scripts/create-edgeapp.sh <vmid> <name>
```

## 3) Wait For First Boot, Then Check Logs (on the VM)

```bash
cloud-init status --long
sudo tail -n 200 /var/log/cloud-init-output.log
sudo tail -n 200 /var/log/bootstrap.log
```

For details/troubleshooting:
- `docs/WALKTHROUGH_PROXMOX.md`
- `docs/PROXMOX_SNIPPETS.md`
- `docs/PROXMOX_VM_CREATE.md`


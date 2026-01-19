# Walkthrough: Proxmox End-to-End

Copy/paste friendly steps to go from “nothing” to a provisioned VM using the scripts in `scripts/`.

## 1) One-Time: Create/Enable Snippets Storage

Pick a Proxmox storage ID for snippets (example: `shared-snippets`).

If you already have a storage, ensure it allows snippets:

```bash
pvesm set synology.lan --content snippets,iso,backup,vztmpl
```

Or create a simple directory-based storage dedicated to snippets:

```bash
pvesm add dir synology.lan --path /mnt/pve/synology.lan --content snippets
mkdir -p /mnt/pve/synology.lan/snippets
```

Decide where the snippet files live on disk (example):

```bash
SNIPPETS_DIR=/mnt/pve/synology.lan/snippets
```

Snippets are **flat** in this directory (no subfolders):

```
/mnt/pve/synology.lan/snippets/ci-edgeapp-1201.yaml
```

## 2) One-Time: Prepare a Debian Cloud-Init Template (High Level)

- Install Debian on a VM (from ISO).
- Inside the VM, install cloud-init + QEMU agent:

```bash
sudo apt-get update
sudo apt-get install -y cloud-init qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

- In Proxmox, confirm the VM has a Cloud-Init drive option available, then convert the VM to a template.
- Record the template VMID (used as `TemplateId`).

## 3) Day 2: Create VMs (Single Entrypoint)

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

```bash
/mnt/pve/synology.lan/snippets/ci-<profile>-<vmid>.yaml
```

## 4) Verify On The Guest

Cloud-init status:

```bash
cloud-init status --long
```

Cloud-init output (includes first-boot provisioning output):

```bash
sudo tail -n 200 /var/log/cloud-init-output.log
```

Bootstrap log:

```bash
sudo tail -n 200 /var/log/bootstrap.log
```

Ansible output:

- First boot: it is typically in `/var/log/cloud-init-output.log`.
- Manual reruns: it prints to your terminal when you run the script.

## 5) Rerun Provisioning

Edit variables (profile, repo URL, app image, tokens, etc.):

```bash
sudoedit /etc/bootstrap.env
```

Re-run:

```bash
sudo /opt/bootstrap/repo/scripts/bootstrap.sh
```

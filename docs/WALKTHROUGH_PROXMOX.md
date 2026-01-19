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

## 2) One-Time: Prepare a Debian Cloud-Init Template (High Level)

- Install Debian on a VM (from ISO).
- Inside the VM, install cloud-init + QEMU agent:

```bash
sudo apt-get update
sudo apt-get install -y cloud-init qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

- In Proxmox, confirm the VM has a Cloud-Init drive option available, then convert the VM to a template.

## 3) Sync Snippet Profiles From Git

On the Proxmox host, clone this repo somewhere convenient:

```bash
git clone https://github.com/SamuelMcAravey/infra-bootstrap.git /opt/infra-bootstrap
cd /opt/infra-bootstrap
```

Ensure the snippets subfolders exist:

```bash
bash ./scripts/proxmox-ensure-storage.sh --snippets-dir "$SNIPPETS_DIR"
```

Sync cloud-init profile YAMLs into the snippets storage (flat `ci-*.yaml` in the snippets root):

```bash
REPO_RAW_BASE=https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap
bash ./scripts/proxmox-sync-snippets.sh --snippets-dir "$SNIPPETS_DIR" --ref main
```

List what’s installed:

```bash
bash ./scripts/proxmox-list-snippets.sh --snippets-dir "$SNIPPETS_DIR"
```

## 4) Create a VM (edgeapp Example)

This clones your template and attaches the profile snippet as `cicustom`:

```bash
bash ./scripts/create-edgeapp.sh \
  --vmid <vmid> \
  --name <name> \
  --template-id <template-vmid> \
  --snippets-storage-id synology.lan \
  --storage local-lvm \
  --bridge vmbr0
```

## 5) Logs to Check on the VM

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

## 6) Rerun Provisioning

Edit variables (profile, repo URL, app image, tokens, etc.):

```bash
sudoedit /etc/bootstrap.env
```

Re-run:

```bash
sudo /opt/bootstrap/repo/scripts/bootstrap.sh
```

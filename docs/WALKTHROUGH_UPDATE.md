# Walkthrough: “I Updated The Repo, Now What?”

## 1) Sync Snippets Again (Proxmox Host)

If the cloud-init profiles changed, re-sync them into the snippets storage:

```bash
cd /opt/infra-bootstrap
REPO_RAW_BASE=https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap
SNIPPETS_DIR=/mnt/pve/synology.lan/snippets
bash ./scripts/proxmox-sync-snippets.sh --snippets-dir "$SNIPPETS_DIR" --ref main
```

## 2) Existing VMs: Pull + Rerun Bootstrap (Inside The VM)

```bash
sudo git -C /opt/bootstrap/repo pull --ff-only
sudo /opt/bootstrap/repo/scripts/bootstrap.sh
```

If you need to change variables first:

```bash
sudoedit /etc/bootstrap.env
sudo /opt/bootstrap/repo/scripts/bootstrap.sh
```

## 3) New VMs: Just Create With Scripts (Proxmox Host)

Once snippets are synced, create new VMs with the wrapper scripts:

```bash
cd /opt/infra-bootstrap
bash ./scripts/create-edgeapp.sh --vmid <vmid> --name <name> --template-id <template-vmid> --snippets-storage-id synology.lan
```


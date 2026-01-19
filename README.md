# infra-bootstrap

Bootstrap scripts and cloud-init user-data for provisioning Debian/Ubuntu hosts.

## Walkthroughs (Start Here)

- Proxmox end-to-end: `docs/WALKTHROUGH_PROXMOX.md`
- After updating the repo: `docs/WALKTHROUGH_UPDATE.md`

## Philosophy

Proxmox Cloud-Init handles the machine identity and connectivity layer: networking, hostname, and SSH keys.
This repo handles provisioning and post-install configuration with Ansible.

## Structure

- `cloud-init/`: cloud-init user-data (one file per profile) used during first boot
- `scripts/`: bootstrap helpers (Ansible entrypoints)
- `ansible/`: Ansible playbooks, profiles, and roles
- `systemd/`: unit files and drop-ins
- `templates/`: configuration templates
- `docs/`: operator documentation

## Use With Proxmox

1. Create or import your VM template.
2. Attach a Cloud-Init drive.
3. Set SSH keys, user, and IP configuration in Proxmox.
4. Pick a profile file from `cloud-init/` (for example `edgeapp.yaml`) and set `REPO_URL` (and any required vars).
5. Upload the cloud-init user-data file to the Proxmox snippets store.
6. Point the VM at the snippet:

   ```bash
   qm set <vmid> --cicustom "user=local:snippets/<file>"
   ```

Cloud-Init provides the user, hostname, and networking. Your user-data then runs Ansible from this repo.

## Use Without Proxmox (NoCloud)

If you are not using Proxmox, use the NoCloud data source:

1. Prepare a `user-data` and `meta-data` pair.
2. Build a seed ISO and attach it to the VM.
3. Boot the VM and let cloud-init run the user-data to kick off Ansible provisioning.

Refer to `docs/PROXMOX.md` for the Proxmox workflow and adapt the same `cloud-init/` user-data for NoCloud.

## Profiles

Profiles describe a target system flavor (for example `edgeapp`, `docker-host`, or `base`).
Each profile wires together Ansible roles from this repo to keep provisioning repeatable.

Start by selecting a profile and apply it via the matching cloud-init user-data.


## Commands:

### Install Powershell on Debian/Ubuntu

```bash
sudo bash -c "curl -fsSL https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap/refs/heads/main/scripts/install-pwsh.sh | bash"
```

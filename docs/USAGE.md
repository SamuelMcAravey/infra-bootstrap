# Usage

Provisioning is Ansible-only and runs locally on the target machine (no control plane required).

## Flow

Proxmox → cloud-init → `scripts/bootstrap.sh` → Ansible → roles → systemd/docker

- Proxmox injects user-data and metadata.
- cloud-init installs prerequisites and runs the bootstrap script.
- `scripts/bootstrap.sh` installs Ansible (if needed) and runs `scripts/apply-ansible.sh`.
- Ansible applies roles based on the selected profile.

## Secrets And Prompts

Provisioning uses two files on the VM:

- `/etc/bootstrap.env` (non-secrets; may be `0644`)
- `/etc/bootstrap.secrets.env` (secrets; must be `0600 root:root`)

If required variables are missing and you run `scripts/bootstrap.sh` interactively, it will prompt and write values
to the appropriate file before Ansible runs. For unattended provisioning, inject `/etc/bootstrap.secrets.env`
ahead of time (for example via a Proxmox snippet).

## Profiles vs Roles

- Profiles define ordered role lists in `ansible/profiles/<name>.yml`.
- Roles are Ansible roles in `ansible/roles/` that implement configuration.

Examples:
- `edgeapp` profile: `docker_host`, `zerotier`, `docker_zerotier_nat`, `docker_edge_network`, `app_compose`.
- `docker-host` profile: `docker_host`.
- `app-only` profile: `docker_edge_network`, `app_compose`.

## Re-run Safely

Ansible is idempotent. Re-running provisioning should be safe.

Manual re-run:

```bash
sudo /opt/bootstrap/repo/scripts/bootstrap.sh
```

Quick status check:

```bash
sudo /opt/bootstrap/repo/scripts/status.sh
```

## Why Ansible?

- Idempotency: repeatable runs without accumulating side effects.
- Portability: works across Debian/Ubuntu without a server.
- No control plane: all configuration runs locally on the host.

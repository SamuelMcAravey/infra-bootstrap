# zerotier

Installs and configures ZeroTier on Debian using the official APT repository.
Ensures the `zerotier-one` service is enabled and started, validates `/dev/net/tun`,
and optionally joins a network when a network ID is provided.

Variables (optional):
- `zerotier_network_id`: Network ID to join. Defaults to `ZEROTIER_NETWORK_ID` from `/etc/bootstrap.env` or environment.

Notes:
- If `/dev/net/tun` is missing, the role fails with Proxmox LXC configuration guidance.
- The role waits up to 60 seconds for a `zt*` interface to appear.

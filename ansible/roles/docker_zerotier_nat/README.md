# docker_zerotier_nat

Installs the Docker-to-ZeroTier NAT shim using a systemd oneshot unit and script.
Enables IPv4 forwarding persistently and applies iptables rules to allow Docker
bridge traffic to egress via the ZeroTier interface.

What it does:
- Installs `iptables` if needed.
- Writes `/usr/local/sbin/docker-zerotier-nat.sh`.
- Writes `/etc/systemd/system/docker-zerotier-nat.service`.
- Enables and starts the unit (with daemon-reload).
- Persists `net.ipv4.ip_forward=1` in `/etc/sysctl.d/99-forward.conf`.

Notes:
- The script detects the Docker bridge subnet and `zt*` interface at runtime.

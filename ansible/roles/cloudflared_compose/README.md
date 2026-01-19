# cloudflared_compose

Creates a Docker Compose fragment for running Cloudflared as a container on the edge network.
This role does not install Cloudflared on the host.

Variables:
- `cloudflare_tunnel_token`: Token for the tunnel. Defaults to `CLOUDFLARE_TUNNEL_TOKEN` from `/etc/bootstrap.env`.
- `edge_network_name`: Docker network name. Defaults to `EDGE_NETWORK_NAME` from `/etc/bootstrap.env` or `edge`.

Notes:
- The compose file uses `CLOUDFLARE_TUNNEL_TOKEN` and sets `TUNNEL_TOKEN` for convenience.
- Do not hardcode the origin here; Cloudflared should point to `http://app1:8080` on the same Docker network.

# app_compose

Creates and manages a Docker Compose stack for the `app1` service (and an optional
cloudflared sidecar) on the edge network. The stack is started and supervised by
a systemd unit.

Variables (optional):
- `compose_project_dir`: Directory for the compose project. Defaults to `/srv/app`.
- `app_image`: Image for the `app1` container. Required.
- `app_container_name`: Container name for `app1`. Defaults to `pw_app1`.
- `app_port_publish`: Optional host port mapping (example: `8080:8080`).
- `edge_network_name`: External Docker network name. Defaults to `edge`.

Notes:
- The compose file includes a cloudflared service. `CLOUDFLARE_TUNNEL_TOKEN` is read
  at runtime via the `.env` file or environment, but this role does not write secrets.
- Cloudflared should point to `http://app1:8080` on the same Docker network.

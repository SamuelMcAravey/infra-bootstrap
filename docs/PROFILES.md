# Profiles

Profiles are selected by `PROFILE` in `/etc/bootstrap.env` and map to `ansible/profiles/<profile>.yml`.

## Profile: `edgeapp`

Purpose: Docker host + ZeroTier + NAT + “edge” Docker network + app stack (includes cloudflared).

Ansible roles (from `ansible/profiles/edgeapp.yml`):

- `docker_host`
- `zerotier`
- `docker_zerotier_nat`
- `docker_edge_network`
- `app_compose`

`/etc/bootstrap.env` variables:

- Required:
  - `PROFILE=edgeapp`
  - `REPO_URL` (used by cloud-init bootstrap to clone this repo)
  - `ZEROTIER_NETWORK_ID`
  - `APP_IMAGE`
  - `CLOUDFLARE_TUNNEL_TOKEN`
- Optional (defaults are in roles):
  - `COMPOSE_PROJECT_DIR` (default: `/srv/app`)
  - `EDGE_NETWORK_NAME` (default: `edge`)
  - `APP_CONTAINER_NAME` (default: `pw_app1`)
  - `APP_PORT_PUBLISH` (optional port publish mapping)

## Profile: `app-only`

Purpose: Create the “edge” Docker network + run the app stack (includes cloudflared). Does not install Docker.

Ansible roles (from `ansible/profiles/app-only.yml`):

- `docker_edge_network`
- `app_compose`

`/etc/bootstrap.env` variables:

- Required:
  - `PROFILE=app-only`
  - `REPO_URL` (used by cloud-init bootstrap to clone this repo)
  - `APP_IMAGE`
  - `CLOUDFLARE_TUNNEL_TOKEN`
- Optional:
  - `COMPOSE_PROJECT_DIR` (default: `/srv/app`)
  - `EDGE_NETWORK_NAME` (default: `edge`)
  - `APP_CONTAINER_NAME` (default: `pw_app1`)
  - `APP_PORT_PUBLISH`

## Profile: `docker-host`

Purpose: Install Docker host prerequisites only.

Ansible roles (from `ansible/profiles/docker-host.yml`):

- `docker_host`

`/etc/bootstrap.env` variables:

- Required:
  - `PROFILE=docker-host`
  - `REPO_URL` (used by cloud-init bootstrap to clone this repo)
- Optional:
  - none


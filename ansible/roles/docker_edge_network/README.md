# docker_edge_network

Ensures a Docker network exists for edge workloads.

Variables (optional):
- `edge_network_name`: Name of the Docker network. Defaults to `EDGE_NETWORK_NAME` from `/etc/bootstrap.env` or `edge`.

Behavior:
- Creates the network if missing.
- Does not modify or delete existing networks.

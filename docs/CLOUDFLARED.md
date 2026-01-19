# Cloudflared

Cloudflared should target an origin service on the same Docker network.

Example origin:

`http://app1:8080`

Do not point the tunnel to `localhost` unless the app runs with host networking.

# docker_host

Installs Docker Engine and the Docker Compose plugin on Debian using Docker's official APT repository.
Ensures the Docker service is enabled and running, and adds the `samuel` user to the `docker` group
when that user exists.

Variables (optional):
- `docker_arch`: Defaults to `dpkg --print-architecture` output.
- `ansible_lsb.codename`: Used for the repository codename.

Outputs:
- Logs `docker --version` to confirm Docker is functional.

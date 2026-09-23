# Fluxer services

NixOS manages 24 Podman containers and a storage setup job through
`fluxer.target`. Compose is not used. Service settings derive from the
[upstream stack](https://github.com/fluxerapp/fluxer/blob/34b6ecfbd27f29f2a7b9637ea7685e67e0582b85/deploy/self-hosting/docker-compose.yml).

Each module configures one service or a router and its shard. `environment.nix`
holds shared settings, `secrets.nix` prepares secret files, and `default.nix`
sets up the network and target. Containers have names starting with `fluxer-`;
network aliases retain upstream names such as `api`, `postgres`, and `nats`.

Caddy serves `chat.zekurio.me` through the edge container on `127.0.0.1:8080`.
LiveKit keeps its direct ports, TCP 7881 and UDP 7882. Other backend ports,
including PostgreSQL, stay inside the container network.

Only `unfurl`, `unfurl-shard`, and `media-proxy` use public DNS servers
`1.1.1.1` and `1.0.0.1`. Podman's DNS still resolves container names. Public
DNS prevents Alloy links from resolving to LAN addresses that Fluxer's SSRF
checks reject.

## Storage

The `tank/fluxer` ZFS dataset mounts at `/var/lib/fluxer`. All persistent
Fluxer data, including messages and PostgreSQL transaction logs, lives on
tank and shares its snapshot policy.

| Service | Host directory |
|---|---|
| PostgreSQL data and WAL | `/var/lib/fluxer/postgres` |
| Meilisearch | `/var/lib/fluxer/meilisearch` |
| NATS | `/var/lib/fluxer/nats` |
| Valkey | `/var/lib/fluxer/valkey` |
| Edge data and config | `/var/lib/fluxer/caddy/data`, `/var/lib/fluxer/caddy/config` |
| Attachments | `/var/lib/fluxer/seaweedfs` |

Containers use explicit host bind mounts. Dockerfile volume declarations are
ignored, including in the storage setup job, to prevent anonymous volumes.
An assertion rejects named volumes in Fluxer's container configuration.
The storage guard rejects obsolete Compose volumes. The stack waits for
`tank-datasets.service` before starting.

Fluxer has a dedicated PostgreSQL 16 container with 150 connection slots.
The API, worker, users shard, and messages shard connect to `postgres:5432`
using SCRAM authentication. The `fluxer` role owns its database and has no
superuser privileges. A PostgreSQL post-start command synchronizes its password
from the container environment before the application containers start.
The shared native PostgreSQL server is not used by Fluxer.

The storage setup job creates the buckets and applies the S3 identity. The
API, worker, and media proxy wait for it. Containers with health checks report
readiness to systemd only after their checks pass. Failed health checks stop
the container so systemd can restart it.

## Operations

Deploy using the rebuild steps in the root `AGENTS.md`.

- Inspect services with `systemctl status 'podman-fluxer-*'`.
- Read API logs with `journalctl -u podman-fluxer-api`.
- Restart the stack with `sudo systemctl restart fluxer.target`.
- Check login, messages, attachment uploads, and a voice call after updates.

`services.homelab.fluxer.imageTag` selects the Fluxer application image tag.
For an unchanged moving tag such as `v1`, explicitly pull the application
images before restarting; the default pull policy reuses cached images.
Dependency images have separate tags in their modules. Review upstream
configuration changes before updating either set.

A full reset requires stopping `fluxer.target` and resetting every state
folder together, including PostgreSQL, NATS, Valkey, Meilisearch, and SeaweedFS.
Preserve a database dump and an offline copy or snapshot first. Recreate the
host directories using `systemd-tmpfiles --create --prefix=/var/lib/fluxer`
before starting the stack. Keep recovery copies outside the active dataset.

## Secrets

Edit `fluxer_env` with `sops secrets/adam.yaml`. It contains one unquoted
`NAME=value` line per credential. Keep values on one line without shell quotes
or variable references.

`fluxer-secrets.service` renders mode-0600 files into `/run/fluxer-env`, a
root-only directory. `secret-files.json` maps source keys to service variables.
PostgreSQL, Meilisearch, LiveKit, and storage setup receive separate files.
A secret change restarts the renderer and its consumers. A missing key stops
rendering before any output file changes. Secret values never enter the Nix
store.

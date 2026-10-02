# Fluxer services

NixOS manages 23 Podman containers and a storage setup job through
`fluxer.target`. Compose is not used. Service settings derive from the
[upstream stack](https://github.com/fluxerapp/fluxer/blob/34b6ecfbd27f29f2a7b9637ea7685e67e0582b85/deploy/self-hosting/docker-compose.yml).

Each module configures one service or a router and its shard. `environment.nix`
holds shared settings, `secrets.nix` prepares secret files, and `default.nix`
sets up the network and target. Containers have names starting with `fluxer-`;
network aliases retain upstream names such as `api` and `nats`.

Caddy serves `chat.zekurio.me` through the edge container on `127.0.0.1:8080`.
LiveKit keeps its direct ports, TCP 7881 and UDP 7882. Other backend ports,
stay inside the container network. PostgreSQL runs on the host; the Fluxer
bridge `fluxer0` permits database connections to its gateway at `10.89.42.1`.
The network uses `10.89.42.0/24`. No database firewall port is opened on the LAN.

Only `unfurl`, `unfurl-shard`, and `media-proxy` use public DNS servers
`1.1.1.1` and `1.0.0.1`. Podman's DNS still resolves container names. Public
DNS prevents Alloy links from resolving to LAN addresses that Fluxer's SSRF
checks reject.

## Storage

The `tank/fluxer` ZFS dataset mounts at `/tank/fluxer` for attachment and other
S3 object storage. It has a shared `800G` quota and retains 24 hourly, 30 daily,
and 6 monthly snapshots. `/var/lib/fluxer` stays on the system SSD for search,
queue, cache, and proxy state.

| Service | Disk | Host directory |
|---|---|---|
| PostgreSQL data and WAL | SSD | `/var/lib/postgresql/16` |
| Meilisearch | SSD | `/var/lib/fluxer/meilisearch` |
| NATS | SSD | `/var/lib/fluxer/nats` |
| Valkey | SSD | `/var/lib/fluxer/valkey` |
| Edge data and config | SSD | `/var/lib/fluxer/caddy/data`, `/var/lib/fluxer/caddy/config` |
| SeaweedFS attachments and S3 objects | Pool | `/tank/fluxer/seaweedfs` |

Messages and other application records share Fluxer's PostgreSQL table, so
they stay together on the SSD for fast reads and writes. The shared PostgreSQL
data directory is outside the Fluxer dataset's quota and snapshot policy.
Database backups must be handled separately.

Containers use explicit host bind mounts. Dockerfile volume declarations are
ignored, including in the storage setup job, to prevent anonymous volumes.
An assertion rejects named volumes in Fluxer's container configuration.
The storage guard rejects obsolete Compose volumes. The stack waits for
`tank-datasets.service` before starting.

Fluxer uses the shared native PostgreSQL service. NixOS creates the `fluxer`
database and its unprivileged owner role. The API, worker, users shard, and
messages shard connect to `10.89.42.1` using the host PostgreSQL port and SCRAM
authentication. The host accepts this role/database pair from the Fluxer
subnet. The shared connection limit defaults to 200; Fluxer's four pools use
at most 90 connections.

`fluxer-database.service` waits for PostgreSQL database/role setup and secret
rendering, then applies the password before the database clients start.

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

A full reset requires stopping `fluxer.target`, resetting only the `fluxer`
database on the shared server, and resetting the NATS, Valkey, Meilisearch,
and SeaweedFS state folders together. Do not reset the shared PostgreSQL data
directory. Preserve a database dump and an offline copy or snapshot first.
Recreate the SSD directories using
`systemd-tmpfiles --create --prefix=/var/lib/fluxer`; `tank-datasets.service`
creates the pool directory before the stack starts. Keep recovery copies
outside the active dataset.

### Migrating from the PostgreSQL container

The configuration does not migrate or delete `/var/lib/fluxer/postgres`.
Before switching an existing installation, stop Fluxer's writers and take a
logical dump of its database from the old PostgreSQL 16 container. Restore it
into the native `fluxer` database as the `fluxer` role before starting the new
stack. Keep the old directory and dump until the restored data is verified.
Never copy the container's data directory over the shared PostgreSQL cluster.

This storage layout is for a fresh instance. Existing installations that
mounted `tank/fluxer` at `/var/lib/fluxer` must also move their search, queue,
cache, and proxy directories onto the SSD before switching to this layout.

The old Podman network also needs replacing if it has a different subnet or
bridge name. With the stack stopped, remove its containers and the
`fluxer_fluxer` network without deleting persistent data. The next start
creates the network with the required layout. Startup refuses an incompatible
existing network rather than silently connecting to the wrong gateway.

## Secrets

Edit `fluxer_env` with `sops secrets/adam.yaml`. It contains one unquoted
`NAME=value` line per credential. Keep values on one line without shell quotes
or variable references.

`fluxer-secrets.service` renders mode-0600 files into `/run/fluxer-env`, a
root-only directory. `secret-files.json` maps source keys to service variables.
Database password setup, Meilisearch, LiveKit, and storage setup receive
separate files. Systemd passes the database file to the setup service through
`LoadCredential`; the PostgreSQL user cannot read the other Fluxer secrets.
A secret change restarts the renderer and its consumers. A missing key stops
rendering before any output file changes. Secret values never enter the Nix
store.

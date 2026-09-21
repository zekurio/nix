# Fluxer services

NixOS manages PostgreSQL, 23 Podman containers, and one storage setup job. The settings
match the previously pinned
[upstream stack](https://github.com/fluxerapp/fluxer/blob/34b6ecfbd27f29f2a7b9637ea7685e67e0582b85/deploy/self-hosting/docker-compose.yml).
Compose is no longer used.

Each module configures one service or a router and its shard. `environment.nix`
holds the shared app settings. `secrets.nix` prepares the secret files. `default.nix` sets
up the network and `fluxer.target`. The container names start with `fluxer-`.
Network aliases keep upstream names such as `api` and `nats`.

Caddy serves `chat.zekurio.me` through the edge container on `127.0.0.1:8080`.
LiveKit keeps its direct ports, TCP 7881 and UDP 7882. Other backend ports
stay inside the container network.

Only `unfurl`, `unfurl-shard`, and `media-proxy` use public DNS servers
`1.1.1.1` and `1.0.0.1`. Podman's DNS still resolves container names. Public
DNS prevents Alloy links from resolving to LAN addresses that Fluxer's SSRF
checks reject. Host DNS and SSO settings keep their existing values.

Persistent data uses these directories:

| Service | Host directory |
|---|---|
| PostgreSQL | `/var/lib/postgresql/16` on Adam, shared with the other native databases |
| Meilisearch | `/var/lib/fluxer/meilisearch` |
| NATS | `/var/lib/fluxer/nats` |
| Valkey | `/var/lib/fluxer/valkey` |
| Edge data and config | `/var/lib/fluxer/caddy/data`, `/var/lib/fluxer/caddy/config` |
| Attachments | `/tank/fluxer/seaweedfs` |

Attachments keep the existing ZFS backup policy. The other directories use
the root disk. Containers use bind mounts and no longer use named volumes.

The storage setup job checks the buckets and applies the S3 identity. The
API, worker, and media proxy wait for it to finish. Containers with health
checks report readiness to systemd only after the check passes. Failed health
checks stop the container so systemd can restart it. Normal health check
intervals, retry counts, memory limits, and memory reservations match the
upstream stack.

The API, worker, users shard, and messages shard connect to native PostgreSQL
through a read-only mount of `/run/postgresql`. They use SCRAM authentication
with the existing password. The `fluxer` role owns only the Fluxer database
and has no superuser access. PostgreSQL keeps its existing TCP listeners and
firewall rules. The shared server allows 250 connections.

These four containers wait for database setup and password setup. They restart
with PostgreSQL to remount its socket directory. `fluxer.target` does not stop
the shared database server.

## PostgreSQL migration

Before the first switch, build the new system while Fluxer is still running.
Stop `fluxer.target`, then start only `podman-fluxer-postgres.service` to make
an offline `pg_dump -Fc` backup of the `fluxer` database. Keep the backup in a
root-only directory. Stop the old PostgreSQL service after the dump.

Create a native `fluxer` login role without superuser rights and a database
owned by that role. Use the source encoding and locale. Restore the dump with
`pg_restore --exit-on-error --single-transaction --no-owner --no-privileges
--role=fluxer`. Compare every table's row count and data checksum while the
app stays stopped. After verification, create
`/var/lib/fluxer/.postgresql-migrated`, switch to the new system, and start
`fluxer.target`. The storage guard blocks startup if the old data directory
exists but this marker is missing.

Keep `/var/lib/fluxer/postgres` and the dump until the move is accepted. They
stop receiving writes after the move. A later rollback must copy new native
database writes back before the old container starts.

## Earlier Compose migration

Deploy with the commit, push, and rebuild steps in the root `AGENTS.md`.
Before the first switch, stop the old `fluxer.service` and copy its six
root-disk named volumes into the directories above. Preserve numeric owners,
permissions, ACLs, and extended attributes. Verify the copies while the old
stack stays stopped, then create `/var/lib/fluxer/.named-volumes-migrated`.
The startup guard requires this marker if old named volumes still exist.
Attachments already use their final directory and need no copy.

The first deployment starts the new services. Expect a brief full-stack
outage. Keep the old named volumes as a copy from before the migration.
They stop receiving updates after the switch. The old Compose files in
`/var/lib/fluxer` become unused. Do not start them alongside the new services.

After deployment:

- Inspect the services with `systemctl status 'podman-fluxer-*'`.
- Read API logs with `journalctl -u podman-fluxer-api`.
- Restart the stack with `sudo systemctl restart fluxer.target`.
- Check login, messages, an existing attachment, and a voice call.
- Check that the three preview services resolve `clips.zekurio.me` to its
  public address and can still resolve internal service names.
- Post a fresh Alloy clip link to test its preview.

Change `services.homelab.fluxer.imageTag` to update the Fluxer app images.
Dependency images have separate tags in their modules. Check upstream changes
before updating either set. This conversion keeps the existing image tags.

## Secrets

Edit `fluxer_env` with `sops secrets/adam.yaml`. It contains one unquoted
`NAME=value` line per credential. Keep values on one line. Do not add shell
quotes or variable references.

`fluxer-secrets.service` reads this secret and writes mode-0600 env files into
`/run/fluxer-env`, a root-only directory. `secret-files.json` maps the source
keys to the variable names each service expects. The application containers
keep the shared env settings from the pinned upstream stack. PostgreSQL,
Meilisearch, LiveKit, and storage setup receive separate files.

A secret change restarts the renderer and its consumers. A missing key stops
rendering before any output file changes. Secret values never enter the Nix
store. The migration to `fluxer_env` preserves all existing credentials.

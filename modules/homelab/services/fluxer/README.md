# Fluxer services

NixOS manages 24 Podman containers and one storage setup job. The settings
match the previously pinned
[upstream stack](https://github.com/fluxerapp/fluxer/blob/34b6ecfbd27f29f2a7b9637ea7685e67e0582b85/deploy/self-hosting/docker-compose.yml).
Compose is no longer used.

Each module configures one service or a router and its shard. `environment.nix`
holds the shared app settings and encrypted credentials. `default.nix` sets
up the network and `fluxer.target`. The container names start with `fluxer-`.
Network aliases keep upstream names such as `api`, `postgres`, and `nats`.

Caddy serves `chat.zekurio.me` through the edge container on `127.0.0.1:8080`.
LiveKit keeps its direct ports, TCP 7881 and UDP 7882. Other backend ports
stay inside the container network.

Only `unfurl`, `unfurl-shard`, and `media-proxy` use public DNS servers
`1.1.1.1` and `1.0.0.1`. Podman's DNS still resolves container names. Public
DNS prevents Alloy links from resolving to LAN addresses that Fluxer's SSRF
checks reject. Host DNS and SSO settings keep their existing values.

Persistent data lives under `/var/lib/fluxer`:

| Service | Host directory |
|---|---|
| PostgreSQL | `/var/lib/fluxer/postgres` |
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
upstream stack. PostgreSQL's readiness check uses TCP to exclude its temporary
init server.

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

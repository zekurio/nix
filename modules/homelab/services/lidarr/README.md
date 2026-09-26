Lidarr runs at `https://admin.zekurio.me/lidarr/`, restricted to the LAN and
tailnet like Sonarr and Radarr. It uses the shared `zekurio` admin login.
The API key is the SOPS `lidarr_api_key` secret.

The package pins Lidarr nightly `3.1.6.5078` and the slskd plugin `1.1.4.0`.
Plugin support moved into nightly after the legacy `plugins` channel.
Update the pinned versions and hashes in this module to upgrade them.
Application and plugin updates are managed through Nix.

At startup, the service configures both the Slskd indexer and download client
using `http://127.0.0.1:5030/slskd/` and the existing SOPS `slskd_api_key`.
It adds `/tank/media/music` as a root folder, initially unmonitored, and
registers the beets hook for release imports and upgrades. Choose artists,
monitoring, and quality preferences in Lidarr. The startup configuration
preserves these choices and other indexer filters across restarts.

Lidarr owns Soulseek downloads, imports, and file paths. Its own tag writing
is disabled so beets can enrich tags after import without later overwrites.
The hook uses a temporary database, tags multi-disc releases together, and
never moves or copies files. Copyparty's `/musik-ablage` still feeds the
persistent beets importer. Lidarr watches the music library for those imports.
Downloads started manually in slskd stay there for manual handling; the
plugin only tracks downloads requested through Lidarr.

See `journalctl -u lidarr.service` for startup and provisioning errors.
Beets hook output is captured in Lidarr's debug logs.

Upstream references:

- [Lidarr and beets integration, pattern 1](https://wiki.servarr.com/lidarr/beets-integration)
- [Slskd plugin requirements and behavior](https://github.com/allquiet-hub/Lidarr.Plugin.Slskd)

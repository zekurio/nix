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
monitoring, and artist profile assignments in Lidarr. Startup preserves
these choices and other indexer filters across restarts.

When SABnzbd is enabled, startup also configures its download client at
`http://127.0.0.1:6789/sabnzbd` using the SOPS `sabnzbd_api_key`.
The `lidarr` category repairs and unpacks into
`/mnt/downloads/complete/lidarr`. Lidarr removes completed history entries
after import. Prowlarr manages the Usenet indexers separately.

Startup manages two quality profiles. `Lossless preferred` allows the high
quality lossy group as fallback and upgrades to lossless. It adopts the stock
`Lossless` profile, including its existing artist assignments, and becomes the
music root's default. `Lossless only` excludes lossy downloads. Unknown and
lower quality lossy formats are excluded from both. The lossless formats share
one quality group, so 24-bit files are accepted without forcing a 24-bit upgrade.

Quality ranks before custom format scores. Within a quality group, ordinary
Usenet releases score 0. Slskd's trailing peer annotation scores -1000, with
+400 for an empty queue and cumulative +100 bonuses at 1, 5, and 10 MB/s.
Thus a known Slskd peer scores between -1000 and -300. The minimum accepted
score is -1000, so slow or queued peers remain available as fallback.
Scores use the plugin's rounded speed annotation. An empty queue does not
prove a free upload slot. When speed is unknown the plugin omits all peer
metadata; that result scores 0 too. Slskd indexer priority 50 loses ties to
Adam's Prowlarr Usenet priorities 1 and 2. Title matching cannot distinguish
unknown-speed Slskd results or unrelated titles containing the same suffix.
The managed profiles and scores are reapplied at startup; other profiles and
unrelated custom formats are preserved.

Lidarr owns Soulseek and Usenet downloads, imports, and file paths. Its own tag writing
is disabled so beets can enrich tags after import without later overwrites.
Track renaming is enabled so the naming templates put downloads in album
folders. Without it, plugin downloads land in the artist root and the beets
hook refuses to scan the whole artist. Existing naming templates are preserved.
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

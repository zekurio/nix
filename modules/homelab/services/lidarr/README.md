Lidarr replaces Beets on Adam at `https://admin.zekurio.me/lidarr/`, using the
shared admin login. Navidrome and Soulseek still read `/tank/media/music`.
Beets' database and existing music remain on disk.

On startup, `lidarr-integrations` adds the Soulseek indexer and the Lidarr app
in Prowlarr. Configarr then provisions profiles, download clients and the music
root, and runs daily at 05:00. Prowlarr supplies the music-capable Usenet indexers.

- Default: **Lossless + HQ Lossy**, upgrading MP3/AAC to FLAC/ALAC. **Lossless**
  is available for artists that should never use lossy downloads.
- Within a quality tier, Usenet scores 1000. Soulseek gets 200 for a free slot,
  100 for at least 1 MiB/s, another 50 at 10 MiB/s, and 50 for no queue or 25
  for a queue of 1–9. No peer can outscore Usenet at the same quality.
- Soulseek filters out incomplete track counts and queues above 150, with a
  minimum peer speed setting of 50 KB/s. CF scores do not trigger upgrades.
- Existing albums are monitored; new releases are not automatically monitored.
  Adjust monitoring when adding artists. Existing tags stay intact; new
  downloads get tags and embedded artwork from Lidarr.
- Manual Soulseek downloads are included. Copyparty's `/music-drop` remains an
  inbox; import those uploads with Lidarr's Manual Import from
  `/mnt/downloads/complete/copyparty` once the upload finishes.

The package pins Lidarr 3.1.5.5066 and Tubifarry 2.1.1. Tubifarry can falsely
offer the installed version as an update and log a permission error when its
startup updater tries to overwrite the read-only plugin. The plugin still
loads; update it through Nix, not the Plugins page.

Upstream references: [Tubifarry setup](https://github.com/TypNull/Tubifarry),
[peer ranking](https://github.com/TypNull/Tubifarry/blob/v2.1.1/Tubifarry/Indexers/Soulseek/SlskdIndexer.cs),
[Configarr Lidarr support](https://configarr.de/docs/configuration/experimental-support/).

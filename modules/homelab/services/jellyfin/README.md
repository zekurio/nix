Adam uses Ferrofin 1.3.1 for the Jellyfin API. Nix installs the pinned upstream
Linux binary. The URL, service unit, and `jellyfin` account stay the same.
Findroid and Plezy use the API. Jellium Desktop can load the supplied
Jellyfin web UI. Caddy keeps the existing public web restrictions.

Ferrofin has TVDB support built in. It cannot load Jellyfin's .NET plugins.
Its TVDB provider uses base-language metadata and aired episode order.
It does not select translations during a scan. Library provider choices
carry over from Jellyfin.

Before the first switch, stop Jellyfin and back up `/var/lib/jellyfin`.
Include hidden files and any database WAL and SHM files. Keep media mounted
at the same paths. No flake input update is needed.

On the first start, `jellyfin.service` copies the database, library definitions,
artwork, playlists, collections, and XML settings from `/var/lib/jellyfin`
to `/var/lib/ferrofin`. It does not change the source files. A failed copy
resumes before Ferrofin starts. Ferrofin then adopts the copied database.
Its cache lives in `/var/cache/ferrofin`. Later starts keep the Ferrofin state.
Inviterr updates its reset-file path to `/var/lib/ferrofin/data` at startup.

Check `journalctl -u jellyfin.service` for copy and adoption errors.
Check existing logins, API keys, watch progress, and library images.
Test playback, seeking, audio tracks, and subtitles in Findroid, Plezy,
and Jellium Desktop. Refresh a TVDB series and one episode.
Test an Intel transcode too. Upstream has checked the VAAPI and QSV commands,
but has not yet tested them on Intel hardware.

To return to Jellyfin, set `services.homelab.jellyfin.backend = "jellyfin"`
on Adam and switch the configuration. Jellyfin then uses its original data
directory. Watch progress and other changes made in Ferrofin do not carry
back. Do not let Jellyfin open the adopted Ferrofin database.

Upstream references:

- [Ferrofin release](https://github.com/mangoleaf/ferrofin/releases/tag/v1.3.1)
- [Migration procedure](https://github.com/mangoleaf/ferrofin/blob/v1.3.1/docs/INSTALL.md)
- [TVDB provider](https://github.com/mangoleaf/ferrofin/blob/v1.3.1/crates/ferrofin-providers/src/tvdb.rs)
- [Feature status](https://github.com/mangoleaf/ferrofin/blob/v1.3.1/docs/FEATURES.md)

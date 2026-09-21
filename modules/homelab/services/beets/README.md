Beets imports music on Adam every five minutes from:

- slskd: `/mnt/downloads/complete/slskd`
- Copyparty's `/music-drop`: `/mnt/downloads/complete/copyparty`

The worker waits until files have been idle for two minutes. It waits while
Copyparty has unfinished `.PARTIAL` uploads. It cleans source tags, matches
albums, and moves accepted files into `/tank/media/music`. It skips duplicates
and uncertain matches. Skipped files stay in the inbox for manual review.

Use `beet-music import /path/to/album` on Adam to review an album by hand.
Use `journalctl -u beets-import.service` for worker logs. Beets also writes
`/var/lib/beets/import.log`.

After a successful import, the worker removes unchanged artwork, lyrics,
and other known sidecars from folders whose audio files were all moved.
It keeps skipped audio, changed sidecars, partial uploads, and unknown files.
It also removes empty inbox folders. Copyparty's `.hist` folders stay intact.
A daily slskd job removes empty completed and incomplete download folders
that have been idle for more than a day. It never removes files.

The migration from Lidarr uses a ZFS snapshot and a database backup before
repairing library paths and importing missing albums. The Lidarr state,
API secret, and Prowlarr application are removed as part of that migration.

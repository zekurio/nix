Beets imports music on Adam every five minutes from Copyparty's
`/musik-ablage` at `/mnt/downloads/complete/copyparty`.

Lidarr manages Soulseek downloads and imports. Beets no longer scans the slskd
download directory. After a Lidarr import or upgrade, a separate beets hook
enriches the album's tags in place, using the same metadata, artwork, and
lyrics settings. It uses a temporary database and never moves or copies files.
The hook shares the `beet-music` lock with the Copyparty worker.

The worker waits until files have been idle for two minutes. It waits while
Copyparty has unfinished `.PARTIAL` uploads. It cleans source tags, matches
albums, and moves accepted files into `/tank/media/music`. It skips duplicates
and uncertain matches. Skipped files stay in the inbox for manual review.

Use `beet-music import /path/to/album` on Adam to review an album by hand.
Use `journalctl -u beets-import.service` for worker logs. Beets also writes
`/var/lib/beets/import.log`.

Imports fetch metadata, covers, and plain lyrics. A failed lyrics lookup keeps
existing lyrics. `beet-music` serializes library commands with a lock. Use this
wrapper for manual changes so they cannot overlap a scheduled import.

After a successful import, the worker removes unchanged artwork, lyrics,
and other known sidecars from folders whose audio files were all moved.
It keeps skipped audio, changed sidecars, partial uploads, and unknown files.
It also removes empty inbox folders. Copyparty's `.hist` folders stay intact.
A daily slskd job removes empty completed and incomplete download folders
that have been idle for more than a day. It never removes files.

The earlier migration from Lidarr used a ZFS snapshot and a database backup
before repairing library paths and importing missing albums. That migration
removed the old Lidarr state, API secret, and Prowlarr application. The current
Lidarr service has a new API secret and keeps the Copyparty importer.

The 2026-09-21 migration keeps these recovery and review records on Adam:

- Music snapshot: `tank/media@before-beets-migration-20260921`
- Original beets state and last legacy download:
  `/var/backups/beets-migration-20260921/`
- Lyrics results: `/var/lib/beets/migration-lyrics-report.json`
- FLAC header repairs and decoded-audio hashes:
  `/var/lib/beets/migration-flac-repairs.json`
- Final file, tag, and cover audit:
  `/var/lib/beets/migration-final-audit.json`

The migration repaired stale library paths, registered untracked music, and
imported the last legacy download. It also repaired 20 FLAC stream headers
without changing their decoded audio. Lookup failures stay in the local
reports for later review. Keep the snapshot and backup until that review ends.

# Alloy 0.0.1 database reset

Upstream commit `33b461ce989d9bb82469dbfe66ac5f276224c499` replaces the
migration history and removes social features and separate audio tracks.
The active database is now `alloy_001`; `alloy_v1` and the older `alloy`
database are retained. Do not point the new binary at either old database.

Deployment backups are under `/tank/alloy/backups/reset-001-20260913`.
`final.pgdump`, `assets.tar`, and `clips.tar` have a `SHA256SUMS` manifest;
`media.sha256` covers the original files and `source-tables.txt` records
counts and SHA-256 fingerprints for all source tables. `previous-system`
records the rollback generation. The held ZFS snapshot is
`tank/alloy@pre-alloy-001-20260913`. Retain these backups and both old databases.

`scripts/alloy-reset-001.sql` operates only on a restored copy named
`alloy_001` or `alloy_001_rehearsal`. It retains all 27 original tables in
`alloy_legacy`, retains the original journal in `alloy_legacy_drizzle`,
creates the exact upstream schema, and copies all 19 supported tables.
The app cannot access the archive schemas. Removed comments, likes,
follows, notifications, audio-track rows, and clip columns remain there.

Every copied value is compared with the source using `EXCEPT ALL` in both
directions, with constraints enabled, before the transaction commits.
The new journal contains the actual baseline SHA-256 and timestamp, so
Alloy's normal Drizzle migrator can apply subsequent upstream migrations.
The startup check requires the completed import and that baseline entry;
it never repeats the import and permits later journal entries.

## Procedure

1. Build the pinned package and system before stopping Alloy. Verify that
   `share/alloy/migrations/0000_bumpy_lethal_legion.sql` hashes to
   `c41ec7134cfaa45adaab6baaa794778eb2149844e5810edb2b96048b6928154f`.
2. Rehearse with a fresh custom-format `pg_dump` of `alloy_v1`, restored
   into `alloy_001_rehearsal`, and run the SQL with `baseline_file` pointing
   at the verified package file. Run `scripts/alloy-reset-check.cjs` as
   `alloy` with the package path as its argument. It checks the packaged
   migrator, a synthetic next migration, and repeat startup on this isolated
   database. It deliberately leaves the probe only in the rehearsal database.
3. Stop Alloy. Take a final database dump, a ZFS snapshot of `tank/alloy`,
   and a verified tar archive of `/var/lib/alloy/assets`. Keep backups in
   a root-owned mode-0700 directory under `/tank/alloy/backups`.
4. Create `alloy_001` owned by `alloy`, restore the final dump using
   `pg_restore --exit-on-error --single-transaction`, and run the SQL as
   postgres with `psql -X -v ON_ERROR_STOP=1 -v baseline_file=...`.
5. Compare all 27 archived tables with the stopped source, verify media
   checksums, then activate the new system. Check service logs, HTTP
   responses, media playback, and the migration journal after a restart.

Never overwrite an existing target or backup to retry. An import failure
rolls back the SQL transaction; inspect it before deciding how to retry.
Before the new server accepts writes, rollback is the previous system
generation using `alloy_v1` and the retained media. After new writes,
stop Alloy and preserve `alloy_001` and current media before reconciliation;
switching to the old database alone would hide those new writes.

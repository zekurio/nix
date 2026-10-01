#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
target_dir=$2
pending="$target_dir/.jellyfin-copy-pending"
complete="$target_dir/.jellyfin-copy-complete"

# The same systemd unit runs both servers. It stops Jellyfin before this copy.
# Keep a marker until all files arrive so a failed copy can resume on restart.
for database in ferrofin.db jellyfin.db data/jellyfin.db; do
  if [[ -e "$target_dir/$database" ]]; then
    if [[ -f "$complete" || ! -f "$pending" ]]; then
      exit 0
    fi
    if [[ "$database" == ferrofin.db || -e "$target_dir/$database.pre-ferrofin" ]]; then
      echo "Cannot resume the copy after Ferrofin has opened the database." >&2
      exit 1
    fi
  fi
done

if [[ -f "$complete" ]]; then
  echo "The copied Jellyfin database is missing. Restore it before startup." >&2
  exit 1
fi

if [[ "$source_dir" == "$target_dir" || ! -f "$source_dir/data/jellyfin.db" ]]; then
  echo "Cannot copy Jellyfin state: check the source data directory." >&2
  exit 1
fi

mkdir -p "$target_dir/data"
touch "$pending"
# A stopped Jellyfin server can remove these files between copy attempts.
rm -f "$target_dir/data/jellyfin.db-wal" "$target_dir/data/jellyfin.db-shm"
for database in jellyfin.db jellyfin.db-wal jellyfin.db-shm; do
  if [[ -f "$source_dir/data/$database" ]]; then
    rsync -a "$source_dir/data/$database" "$target_dir/data/"
  fi
done

# .NET plugins cannot run in Ferrofin. Copy library state and XML settings only.
for directory in data/playlists data/collections root/default metadata config; do
  if [[ -d "$source_dir/$directory" ]]; then
    mkdir -p "$target_dir/$directory"
    rsync -a "$source_dir/$directory/" "$target_dir/$directory/"
  fi
done

touch "$complete"
rm "$pending"
echo "Copied Jellyfin state to $target_dir. The source files are unchanged."

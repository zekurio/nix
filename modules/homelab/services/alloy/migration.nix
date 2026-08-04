{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.alloy;
    legacyDatabase = "alloy";
    database = "alloy_v1";
    user = config.services.alloy-server.user;
    databaseUser = config.services.alloy-server.database.user;
    backupDir = "/tank/alloy/backups";
    backupFile = "${backupDir}/alloy-pre-v1.0.1.pgdump";
    assetsBackupFile = "${backupDir}/alloy-assets-pre-v1.0.1.tar";
    clipsBackupFile = "${backupDir}/alloy-clips-pre-v1.0.1.tar";
    baselineHash = "21aec20f907840648113512b4e6067c1e7f41c489ea53ec8a24b7dcb1912d2e1";
    baselineTimestamp = "1785837473732";
    baselineMigration = "${config.services.alloy-server.package}/share/alloy/migrations/0000_blushing_talos.sql";
    legacyJournal = lib.concatStringsSep "," [
      "4ad1afcad3e94b92c62efc3fcfbcaf2ae631b692b17b1795c3277df7493d8536:1783591694111"
      "28a14c9621760fe468caf64ac776d51f7a41854fa473de49fe463151c8bce59c:1784295165128"
      "1931b141aff788945c709f82c9c9b9fbae1a390ec690b49f9d4aeccafdac1fdc:1784531762214"
      "31da0737231cb4e4be72a0ab762b73c9bde939d1cc8c6a6c70c328bd493385b7:1784555028334"
      "23760ffd2060969798efa79bc44bf7851b13c9af6b8cd58b98fb394c4c79b76a:1784968040227"
      "9a603ab3a78e8077118005aa3462cf046a4aa1d7c3853bddd345ca4729570260:1785159617472"
      "4bde354d92852819a77f50e903537963ea1677c90855eada340235d0dbf56017:1785168465078"
      "e70b8459f5e458995c83f0003c69aaa5b70c5d3be04c393eb14c2b831f5c2168:1785420973650"
    ];
    migrate = pkgs.writeShellApplication {
      name = "alloy-v1-migrate";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnutar
        config.services.postgresql.package
        pkgs.util-linux
      ];
      text = ''
                legacy_database=${lib.escapeShellArg legacyDatabase}
                database=${lib.escapeShellArg database}
                alloy_user=${lib.escapeShellArg user}
                database_user=${lib.escapeShellArg databaseUser}
                backup_dir=${lib.escapeShellArg backupDir}
                backup_file=${lib.escapeShellArg backupFile}
                assets_backup_file=${lib.escapeShellArg assetsBackupFile}
                clips_backup_file=${lib.escapeShellArg clipsBackupFile}
                baseline_migration=${lib.escapeShellArg baselineMigration}
                baseline_hash=${lib.escapeShellArg baselineHash}
                baseline_timestamp=${lib.escapeShellArg baselineTimestamp}
                expected_legacy_journal=${lib.escapeShellArg legacyJournal}
                expected_baseline_journal="$baseline_hash:$baseline_timestamp"
                backup_tmp=""

                cleanup() {
                  if [[ -n "$backup_tmp" ]]; then
                    rm -f "$backup_tmp"
                  fi
                }
                trap cleanup EXIT

                postgres() {
                  runuser --user postgres -- env PGUSER=postgres PGDATABASE=postgres "$@"
                }

                alloy() {
                  runuser --user "$alloy_user" -- env PGUSER="$database_user" "$@"
                }

                database_exists() {
                  [[ "$(postgres psql -XAtq --dbname=postgres --command="select 1 from pg_database where datname = '$1'")" == 1 ]]
                }

                migration_journal() {
                  local db=$1
                  if [[ "$(postgres psql -XAtq --dbname="$db" --command="select to_regclass('drizzle.__drizzle_migrations') is not null")" != t ]]; then
                    printf 'absent\n'
                    return
                  fi
                  postgres psql -XAtq --dbname="$db" \
                    --command="select coalesce(string_agg(hash || ':' || created_at::text, ',' order by created_at), ''') from drizzle.__drizzle_migrations"
                }

                public_tables() {
                  postgres psql -XAtq --dbname="$1" \
                    --command="select coalesce(string_agg(table_name, ',' order by table_name), ''') from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE'"
                }

                target_marker_state() {
                  if [[ "$(postgres psql -XAtq --dbname="$database" --command="select to_regclass('alloy_migration.v1_import') is not null")" != t ]]; then
                    printf 'absent\n'
                    return
                  fi
                  postgres psql -XAtq --dbname="$database" \
                    --command="select case when complete then 'complete' else 'in_progress' end from alloy_migration.v1_import where id"
                }

                validate_target_history() {
                  local journal
                  journal=$(migration_journal "$database")
                  if [[ "$journal" != "$expected_baseline_journal" && "$journal" != "$expected_baseline_journal,"* ]]; then
                    echo "Alloy v1 database has an unexpected migration journal: $journal" >&2
                    return 1
                  fi
                }

                validate_target_baseline() {
                  validate_target_history
                  local journal
                  journal=$(migration_journal "$database")
                  if [[ "$journal" != "$expected_baseline_journal" ]]; then
                    echo "Alloy import target is not at the exact v1.0.1 baseline: $journal" >&2
                    return 1
                  fi

                  postgres psql -XAtq --dbname="$database" --set=ON_ERROR_STOP=1 <<'SQL' >/dev/null
        DO $validate$
        BEGIN
          IF NOT EXISTS (
            SELECT FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'notification'
              AND column_name = 'actor_id'
              AND is_nullable = 'YES'
          ) THEN
            RAISE EXCEPTION 'notification.actor_id is not nullable';
          END IF;

          IF NOT EXISTS (
            SELECT FROM pg_constraint
            WHERE conrelid = 'public.notification'::regclass
              AND conname = 'notification_kind_check'
              AND pg_get_constraintdef(oid) LIKE '%clip_processing_failed%'
          ) THEN
            RAISE EXCEPTION 'notification_kind_check is not the Alloy 1.0 constraint';
          END IF;
        END
        $validate$;
        SQL
                }

                table_fingerprint() {
                  local db=$1 table=$2
                  postgres psql -XAtq --dbname="$db" --command="
                    select count(*)::text || ':' || md5(coalesce(string_agg(row_hash, ''' order by row_hash), '''))
                    from (select md5(to_jsonb(t)::text) as row_hash from public.\"$table\" t) rows
                  "
                }

                compare_table_data() {
                  local table source_fingerprint target_fingerprint failed=0
                  while IFS= read -r table; do
                    [[ -z "$table" ]] && continue
                    if [[ ! "$table" =~ ^[a-z0-9_]+$ ]]; then
                      echo "Refusing unsafe table name: $table" >&2
                      return 1
                    fi
                    source_fingerprint=$(table_fingerprint "$legacy_database" "$table")
                    target_fingerprint=$(table_fingerprint "$database" "$table")
                    if [[ "$source_fingerprint" != "$target_fingerprint" ]]; then
                      echo "Data fingerprint mismatch for $table" >&2
                      failed=1
                    fi
                  done < <(postgres psql -XAtq --dbname="$legacy_database" --command="select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE' order by table_name")
                  return "$failed"
                }

                verify_recorded_backups() {
                  local recorded database_hash assets_hash clips_hash
                  recorded=$(postgres psql -XAtq --field-separator=: --dbname="$database" \
                    --command="select backup_sha256, assets_backup_sha256, clips_backup_sha256 from alloy_migration.v1_import where id and complete")
                  IFS=: read -r database_hash assets_hash clips_hash <<<"$recorded"
                  [[ -f "$backup_file" && "$(sha256sum "$backup_file" | cut -d' ' -f1)" == "$database_hash" ]]
                  [[ -f "$assets_backup_file" && "$(sha256sum "$assets_backup_file" | cut -d' ' -f1)" == "$assets_hash" ]]
                  [[ -f "$clips_backup_file" && "$(sha256sum "$clips_backup_file" | cut -d' ' -f1)" == "$clips_hash" ]]
                  pg_restore --list "$backup_file" >/dev/null
                  tar --list --file="$assets_backup_file" >/dev/null
                  tar --list --file="$clips_backup_file" >/dev/null
                }

                if database_exists "$database" && [[ "$(target_marker_state)" == complete ]]; then
                  validate_target_history
                  verify_recorded_backups
                  echo "Alloy v1 data migration is already complete"
                  exit 0
                fi

                legacy_storage_has_data() {
                  local path
                  for path in /tank/alloy/clips /var/lib/alloy/assets; do
                    if [[ -d "$path" && -n "$(find "$path" -type f -print -quit)" ]]; then
                      return 0
                    fi
                  done
                  return 1
                }

                if ! database_exists "$legacy_database"; then
                  if legacy_storage_has_data; then
                    echo "Legacy Alloy storage exists but its database is missing; refusing to start empty" >&2
                    exit 1
                  fi
                  # A genuinely new installation has nothing to import. Create the
                  # database; Alloy will initialize it with its normal migrator.
                  if ! database_exists "$database"; then
                    postgres createdb --owner="$database_user" "$database"
                  fi
                  echo "No pre-1.0 Alloy database or storage found; no data migration is needed"
                  exit 0
                fi

                actual_legacy_journal=$(migration_journal "$legacy_database")
                if [[ "$actual_legacy_journal" != "$expected_legacy_journal" ]]; then
                  echo "Refusing to migrate an unexpected pre-1.0 database journal" >&2
                  echo "Found: $actual_legacy_journal" >&2
                  exit 1
                fi

                actual_baseline_hash=$(sha256sum "$baseline_migration" | cut -d' ' -f1)
                if [[ "$actual_baseline_hash" != "$baseline_hash" ]]; then
                  echo "Alloy v1 baseline hash mismatch: $actual_baseline_hash" >&2
                  exit 1
                fi

                if [[ -L "$backup_dir" || (-e "$backup_dir" && ! -d "$backup_dir") ]]; then
                  echo "Refusing unsafe backup path: $backup_dir" >&2
                  exit 1
                fi
                if [[ ! -d "$backup_dir" ]]; then
                  mkdir --mode=0700 "$backup_dir"
                fi
                if [[ "$(stat --format='%u:%g:%a' "$backup_dir")" != 0:0:700 ]]; then
                  echo "Backup directory must be owned by root:root with mode 0700" >&2
                  exit 1
                fi

                required_bytes=1073741824
                for path in /tank/alloy/clips /var/lib/alloy/assets; do
                  path_bytes=$(du --summarize --bytes "$path" | cut -f1)
                  required_bytes=$((required_bytes + path_bytes))
                done
                available_bytes=$(df --block-size=1 --output=avail "$backup_dir" | tail -n 1)
                if (( available_bytes < required_bytes )); then
                  echo "Not enough free space for verified Alloy migration backups" >&2
                  exit 1
                fi

                backup_tmp=$(mktemp "$backup_file.tmp.XXXXXX")
                postgres pg_dump --format=custom --dbname="$legacy_database" >"$backup_tmp"
                pg_restore --list "$backup_tmp" >/dev/null
                chmod 0600 "$backup_tmp"
                mv --force "$backup_tmp" "$backup_file"
                backup_tmp=""
                backup_hash=$(sha256sum "$backup_file" | cut -d' ' -f1)

                backup_tmp=$(mktemp "$assets_backup_file.tmp.XXXXXX")
                tar --create --file="$backup_tmp" --directory=/var/lib/alloy assets
                tar --compare --file="$backup_tmp" --directory=/var/lib/alloy
                chmod 0600 "$backup_tmp"
                mv --force "$backup_tmp" "$assets_backup_file"
                backup_tmp=""
                assets_backup_hash=$(sha256sum "$assets_backup_file" | cut -d' ' -f1)

                backup_tmp=$(mktemp "$clips_backup_file.tmp.XXXXXX")
                tar --create --file="$backup_tmp" --directory=/tank/alloy clips
                tar --compare --file="$backup_tmp" --directory=/tank/alloy
                chmod 0600 "$backup_tmp"
                mv --force "$backup_tmp" "$clips_backup_file"
                backup_tmp=""
                clips_backup_hash=$(sha256sum "$clips_backup_file" | cut -d' ' -f1)

                if database_exists "$database"; then
                  target_state=$(target_marker_state)
                  if [[ "$target_state" == in_progress ]]; then
                    postgres dropdb "$database"
                  elif [[ "$target_state" == absent && "$(migration_journal "$database")" == absent && -z "$(public_tables "$database")" ]]; then
                    postgres dropdb "$database"
                  else
                    echo "Refusing to replace an unrecognized Alloy v1 database" >&2
                    exit 1
                  fi
                fi
                postgres createdb --owner="$database_user" "$database"

                postgres psql -X --dbname="$database" --set=ON_ERROR_STOP=1 \
                  --set=source_database="$legacy_database" \
                  --set=source_journal="$actual_legacy_journal" \
                  --set=backup_sha256="$backup_hash" \
                  --set=assets_backup_sha256="$assets_backup_hash" \
                  --set=clips_backup_sha256="$clips_backup_hash" <<'SQL'
        CREATE SCHEMA alloy_migration;
        CREATE TABLE alloy_migration.v1_import (
          id boolean PRIMARY KEY DEFAULT true CHECK (id),
          complete boolean NOT NULL,
          source_database text NOT NULL,
          source_journal text NOT NULL,
          backup_sha256 text NOT NULL,
          assets_backup_sha256 text NOT NULL,
          clips_backup_sha256 text NOT NULL,
          completed_at timestamp with time zone
        );
        INSERT INTO alloy_migration.v1_import (
          id,
          complete,
          source_database,
          source_journal,
          backup_sha256,
          assets_backup_sha256,
          clips_backup_sha256
        )
        VALUES (
          true,
          false,
          :'source_database',
          :'source_journal',
          :'backup_sha256',
          :'assets_backup_sha256',
          :'clips_backup_sha256'
        );
        SQL

                {
                  cat "$baseline_migration"
                  cat <<'SQL'
        CREATE SCHEMA drizzle;
        CREATE TABLE drizzle.__drizzle_migrations (
          id serial PRIMARY KEY,
          hash text NOT NULL,
          created_at bigint
        );
        INSERT INTO drizzle.__drizzle_migrations (hash, created_at)
        VALUES (:'baseline_hash', :'baseline_timestamp');
        SQL
                } | alloy psql -X --dbname="$database" --set=ON_ERROR_STOP=1 \
                  --single-transaction \
                  --set=baseline_hash="$baseline_hash" \
                  --set=baseline_timestamp="$baseline_timestamp"

                validate_target_baseline

                source_tables=$(public_tables "$legacy_database")
                target_tables=$(public_tables "$database")
                if [[ "$source_tables" != "$target_tables" ]]; then
                  echo "Pre-1.0 and v1 table sets differ; refusing the import" >&2
                  exit 1
                fi

                # Root opens the protected archive before pg_restore drops to
                # postgres, so the backup directory need not expose app data.
                postgres pg_restore \
                  --data-only \
                  --schema=public \
                  --disable-triggers \
                  --single-transaction \
                  --exit-on-error \
                  --dbname="$database" \
                  <"$backup_file"
                compare_table_data

                postgres psql -X --dbname="$database" --set=ON_ERROR_STOP=1 \
                  --command="update alloy_migration.v1_import set complete = true, completed_at = now() where id and not complete"

                validate_target_baseline
                verify_recorded_backups
                echo "Imported and verified all pre-1.0 Alloy data in the fresh v1 database"
                echo "The original database and storage were left intact; backups are in $backup_dir"
      '';
    };
  in {
    config = lib.mkIf cfg.enable {
      # Alloy 1.0 deliberately rejects the development migration journal. Keep
      # the old database untouched for rollback and import its rows into a new
      # database initialized from the supported 1.0 baseline.
      services.alloy-server.database = {
        name = database;
        # The upstream module can only create a database whose name matches its
        # role. The migration creates alloy_v1 with the existing alloy role.
        createDB = false;
      };
      services.postgresql.ensureUsers = [
        {
          name = databaseUser;
          ensureClauses.login = true;
        }
      ];

      systemd.services.alloy-server.serviceConfig = {
        # '+' runs the backup/import step outside the service's user and
        # filesystem sandbox before systemd starts the server itself.
        ExecStartPre = lib.mkBefore ["+${lib.getExe migrate}"];
        TimeoutStartSec = "1h";
      };
    };
  };
}

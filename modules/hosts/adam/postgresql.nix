{
  config,
  lib,
  ...
}: let
  postgres = config.services.postgresql.package;
  psql = lib.getExe' postgres "psql";
  reindexdb = lib.getExe' postgres "reindexdb";
  systemctl = lib.getExe' config.systemd.package "systemctl";
in {
  systemd.services.postgresql-setup.preStart = ''
    check_connection() {
      ${psql} -d postgres -Atq -v ON_ERROR_STOP=1 \
        -c "SELECT NOT pg_is_in_recovery();" \
        | grep -qx t
    }

    while ! check_connection 2> /dev/null; do
      if ! ${systemctl} is-active --quiet postgresql.service; then
        exit 1
      fi
      sleep 0.1
    done

    needs_collation_refresh() {
      local database="$1"

      ${psql} -d postgres -Atq -v ON_ERROR_STOP=1 \
        -c "SELECT datcollversion IS DISTINCT FROM pg_database_collation_actual_version(oid) FROM pg_database WHERE datname = '$database';" \
        | grep -qx t
    }

    refresh_collation() {
      local database="$1"

      if ! needs_collation_refresh "$database"; then
        return
      fi

      ${reindexdb} --dbname="$database"
      ${psql} -d postgres -v ON_ERROR_STOP=1 \
        -c "ALTER DATABASE \"$database\" REFRESH COLLATION VERSION;"
    }

    refresh_collation postgres
    refresh_collation template1
  '';
}

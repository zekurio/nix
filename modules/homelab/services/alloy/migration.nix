{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.alloy;
    database = "alloy_001";
    databaseUser = config.services.alloy-server.database.user;
    checkMigration = pkgs.writeShellApplication {
      name = "alloy-check-migration";
      runtimeInputs = [config.services.postgresql.package pkgs.util-linux];
      text = ''
        # Never reimport stale data on restart. Later migrations run in Alloy.
        runuser --user postgres -- psql -X --username=postgres --dbname=${database} --set=ON_ERROR_STOP=1 <<'SQL'
        DO $check$
        BEGIN
          IF NOT EXISTS (SELECT FROM alloy_migration.reset_001 WHERE complete)
             OR NOT EXISTS (
               SELECT FROM drizzle.__drizzle_migrations
               WHERE hash = 'c41ec7134cfaa45adaab6baaa794778eb2149844e5810edb2b96048b6928154f'
                 AND created_at = 1789247789003
             ) THEN
            RAISE EXCEPTION 'Verified Alloy 0.0.1 import is required; see docs/alloy-reset.md';
          END IF;
        END
        $check$;
        SQL
      '';
    };
  in {
    config = lib.mkIf cfg.enable {
      # Keep alloy_v1 untouched and its full contents in alloy_001.alloy_legacy.
      # The one-time offline import is documented in docs/alloy-reset.md.
      services.alloy-server.database = {
        name = database;
        createDB = false;
      };
      services.postgresql.ensureUsers = [
        {
          name = databaseUser;
          ensureClauses.login = true;
        }
      ];
      systemd.services.alloy-server.serviceConfig.ExecStartPre =
        lib.mkBefore ["+${lib.getExe checkMigration}"];
    };
  };
}

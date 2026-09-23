{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
    clients = ["fluxer-api" "fluxer-worker" "fluxer-users-shard" "fluxer-messages-shard"];
    initSql = pkgs.writeText "fluxer-postgres-init.sql" ''
      CREATE ROLE fluxer LOGIN;
      ALTER DATABASE fluxer OWNER TO fluxer;
    '';
  in {
    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = ["d /var/lib/fluxer/postgres 0700 70 70 -"];
      virtualisation.oci-containers.containers =
        lib.genAttrs clients (_: {dependsOn = ["fluxer-postgres"];})
        // {
          fluxer-postgres = {
            image = "docker.io/library/postgres:16-alpine";
            environment = {
              POSTGRES_DB = "fluxer";
              POSTGRES_USER = "postgres";
              POSTGRES_INITDB_ARGS = "--auth-host=scram-sha-256";
            };
            environmentFiles = ["/run/fluxer-env/fluxer-postgres.env"];
            cmd = ["postgres" "-c" "max_connections=150"];
            # PGDATA includes pg_wal: messages and transaction logs both live on tank.
            volumes = [
              "/var/lib/fluxer/postgres:/var/lib/postgresql/data"
              "${initSql}:/docker-entrypoint-initdb.d/fluxer.sql:ro"
            ];
            podman.sdnotify = "healthy";
            extraOptions = [
              "--memory=1073741824"
              "--health-interval=10s"
              "--health-timeout=5s"
              "--health-retries=10"
              "--health-start-period=1m"
              "--health-on-failure=kill"
              "--health-cmd=pg_isready -h 127.0.0.1 -U postgres -d fluxer"
            ];
          };
        };
      # Keep the application role unprivileged and apply credential rotations
      # before dependent containers start. psql reads the secret inside the container.
      systemd.services.podman-fluxer-postgres.postStart = ''
        podman exec -i --user postgres fluxer-postgres psql -v ON_ERROR_STOP=1 -U postgres -d fluxer <<'SQL'
        \getenv fluxer_password POSTGRES_PASSWORD
        ALTER ROLE fluxer PASSWORD :'fluxer_password';
        SQL
      '';
    };
  };
}

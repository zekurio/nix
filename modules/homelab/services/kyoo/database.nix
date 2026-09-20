{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: {
    config = lib.mkIf config.services.homelab.kyoo.enable {
      systemd.tmpfiles.rules = ["d /var/lib/kyoo/postgres 0700 999 999 -"];
      sops.secrets.kyoo_postgres_password = {};
      sops.templates."kyoo-postgres.env" = {
        content = ''
          POSTGRES_PASSWORD=${config.sops.placeholder.kyoo_postgres_password}
        '';
        restartUnits = ["podman-kyoo-postgres.service"];
      };
      sops.templates."kyoo-database-client.env" = {
        content = ''
          PGPASSWORD=${config.sops.placeholder.kyoo_postgres_password}
        '';
        restartUnits = ["podman-kyoo-api.service" "podman-kyoo-auth.service" "podman-kyoo-scanner.service" "podman-kyoo-transcoder.service"];
      };

      virtualisation.oci-containers.containers =
        {
          kyoo-postgres = {
            image = "docker.io/library/postgres:18";
            environment = {
              POSTGRES_USER = "kyoo";
              POSTGRES_DB = "kyoo";
              POSTGRES_HOST_AUTH_METHOD = "scram-sha-256";
            };
            environmentFiles = [config.sops.templates."kyoo-postgres.env".path];
            volumes = ["/var/lib/kyoo/postgres:/var/lib/postgresql"];
            # Wait for TCP readiness. The init server accepts only local sockets.
            podman.sdnotify = "healthy";
            extraOptions = [
              "--health-cmd=pg_isready -h 127.0.0.1 -U kyoo -d kyoo"
              "--health-interval=5s"
              "--health-timeout=5s"
              "--health-start-period=30s"
              "--health-retries=5"
              "--health-on-failure=kill"
            ];
          };
        }
        // lib.genAttrs ["kyoo-api" "kyoo-auth" "kyoo-scanner" "kyoo-transcoder"] (_: {
          dependsOn = ["kyoo-postgres"];
          environment = {
            PGUSER = "kyoo";
            PGDATABASE = "kyoo";
            PGHOST = "kyoo-postgres";
            PGPORT = "5432";
          };
          environmentFiles = [config.sops.templates."kyoo-database-client.env".path];
        });
    };
  };
}

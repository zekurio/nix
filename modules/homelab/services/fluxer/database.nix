{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
    clients = ["fluxer-api" "fluxer-worker" "fluxer-users-shard" "fluxer-messages-shard"];
  in {
    config = lib.mkIf cfg.enable {
      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        ensureDatabases = ["fluxer"];
        ensureUsers = [
          {
            name = "fluxer";
            ensureDBOwnership = true;
            ensureClauses.login = true;
          }
        ];
        # Fluxer's four pools can use 90 connections; leave room for other host services.
        settings.max_connections = lib.mkDefault 200;
        authentication = ''
          host fluxer fluxer 10.89.42.0/24 scram-sha-256
        '';
      };
      networking.firewall.interfaces.fluxer0.allowedTCPPorts = [config.services.postgresql.settings.port];

      systemd.services =
        lib.genAttrs (map (name: "podman-${name}") clients) (_: {
          requires = ["fluxer-database.service"];
          after = ["fluxer-database.service"];
        })
        // {
          fluxer-database = {
            description = "Set Fluxer's PostgreSQL password";
            requires = ["postgresql-setup.service"];
            after = ["postgresql-setup.service"];
            partOf = ["fluxer.target"];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = "postgres";
              LoadCredential = "postgres-env:/run/fluxer-env/fluxer-postgres.env";
            };
            path = [config.services.postgresql.finalPackage];
            environment.PGPORT = toString config.services.postgresql.settings.port;
            script = ''
              # Read the literal value without shell or EnvironmentFile expansion.
              IFS= read -r entry < "$CREDENTIALS_DIRECTORY/postgres-env"
              export POSTGRES_PASSWORD="''${entry#POSTGRES_PASSWORD=}"
              psql -v ON_ERROR_STOP=1 -U postgres -d postgres <<'SQL'
              SET password_encryption = 'scram-sha-256';
              \getenv fluxer_password POSTGRES_PASSWORD
              ALTER ROLE fluxer PASSWORD :'fluxer_password';
              SQL
            '';
          };
        };
    };
  };
}

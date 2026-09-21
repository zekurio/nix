{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
    clients = ["fluxer-api" "fluxer-worker" "fluxer-users-shard" "fluxer-messages-shard"];
  in {
    config = lib.mkIf cfg.enable {
      services.postgresql = {
        enable = true;
        ensureDatabases = ["fluxer"];
        ensureUsers = [
          {
            name = "fluxer";
            ensureDBOwnership = true;
            ensureClauses = {
              superuser = false;
              createdb = false;
              createrole = false;
              replication = false;
              bypassrls = false;
            };
          }
        ];
        # Reserve the old container's 150 slots alongside the host's 100 slots.
        settings.max_connections = lib.mkDefault 250;
        # Container UIDs cannot use peer authentication. Keep TCP unchanged.
        authentication = lib.mkBefore ''
          local fluxer fluxer scram-sha-256
          local all fluxer reject
        '';
      };

      virtualisation.oci-containers.containers = lib.genAttrs clients (_: {
        volumes = ["/run/postgresql:/run/postgresql:ro"];
      });
      systemd.services =
        lib.genAttrs (map (name: "podman-${name}") clients) (_: {
          requires = ["fluxer-postgres-password.service"];
          after = ["fluxer-postgres-password.service"];
          # Restart containers to remount the socket directory after PostgreSQL restarts.
          partOf = ["postgresql.service"];
        })
        // {
          fluxer-postgres-password = {
            description = "Set the Fluxer PostgreSQL password";
            requires = ["postgresql-setup.service"];
            after = ["postgresql-setup.service"];
            partOf = ["postgresql.service"];
            path = [config.services.postgresql.finalPackage];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = "postgres";
              Group = "postgres";
              LoadCredential = "postgres-env:/run/fluxer-env/fluxer-postgres.env";
              ExecStart = "${lib.getExe pkgs.python3} ${./set-postgres-password.py}";
            };
          };
        };
    };
  };
}

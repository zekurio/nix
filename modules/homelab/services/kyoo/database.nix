{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
    clients = ["kyoo-api" "kyoo-auth" "kyoo-scanner" "kyoo-transcoder"];
    socketDir = "/run/postgresql";
  in {
    config = lib.mkIf cfg.enable {
      # The host's shared cluster. Upstream ships PostgreSQL 18; adam pins
      # the same major. Each component migrates its own schema in the kyoo
      # database; the API creates pg_trgm, a trusted extension the database
      # owner may install.
      services.postgresql = {
        enable = true;
        ensureDatabases = ["kyoo"];
        ensureUsers = [
          {
            name = "kyoo";
            ensureDBOwnership = true;
            ensureClauses.login = true;
          }
        ];
        # Rootful containers share the host's UIDs, so peer auth sees the
        # API, scanner and transcoder as root and auth as its nonroot user.
        authentication = ''
          local kyoo kyoo peer map=kyoo
        '';
        identMap = ''
          kyoo root kyoo
          kyoo kyoo kyoo
        '';
      };

      virtualisation.oci-containers.containers = lib.genAttrs clients (_: {
        environment = {
          PGHOST = socketDir;
          # Names the socket file (.s.PGSQL.<port>).
          PGPORT = toString config.services.postgresql.settings.port;
          PGUSER = "kyoo";
          PGDATABASE = "kyoo";
        };
        volumes = ["${socketDir}:${socketDir}"];
      });

      systemd.services =
        lib.genAttrs (map (name: "podman-${name}") clients) (_: {
          requires = ["postgresql-setup.service"];
          after = ["postgresql-setup.service"];
        })
        // {
          # The containers bind-mount the socket directory. systemd would
          # otherwise delete and recreate it on every PostgreSQL restart,
          # leaving them with a stale mount.
          postgresql.serviceConfig.RuntimeDirectoryPreserve = "yes";
        };
    };
  };
}

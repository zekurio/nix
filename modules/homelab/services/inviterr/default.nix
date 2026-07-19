{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.inviterr;
    domain = "account.${config.services.homelab.domains.schnitzelflix}";
    port = 4173;
    jellyfinDataDir = config.services.jellyfin.dataDir;
    package = inputs.inviterr.packages.${pkgs.system}.default;
  in {
    imports = [
      inputs.inviterr.nixosModules.default
    ];

    options.services.homelab.inviterr = {
      enable = lib.mkEnableOption "Inviterr user management and invitations with Caddy integration";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.jellyfin.enable;
          message = "services.homelab.inviterr requires services.homelab.jellyfin so password reset PIN files can be read from Jellyfin's data directory.";
        }
      ];

      services.inviterr = {
        enable = true;
        inherit package;
        host = "127.0.0.1";
        inherit port;
        dataDir = "/var/lib/inviterr";
        logLevel = "info";
      };

      systemd.services.inviterr = {
        after = ["jellyfin.service"];
        unitConfig.RequiresMountsFor = [jellyfinDataDir];
        serviceConfig = {
          ReadOnlyPaths = [jellyfinDataDir];
          SupplementaryGroups = ["jellyfin"];
        };
      };

      services.homelab.caddy.virtualHosts."inviterr" = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}

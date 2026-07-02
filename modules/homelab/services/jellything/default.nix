{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.jellything;
  domain = "account.schnitzelflix.xyz";
  port = 4173;
  jellyfinDataDir = config.services.jellyfin.dataDir;
  package = inputs.jellything.packages.${pkgs.system}.default;
in {
  imports = [
    inputs.jellything.nixosModules.default
  ];

  options.services.homelab.jellything = {
    enable = lib.mkEnableOption "Jellything user management and invitations with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.homelab.jellyfin.enable;
        message = "services.homelab.jellything requires services.homelab.jellyfin so password reset PIN files can be read from Jellyfin's data directory.";
      }
    ];

    services.jellything = {
      enable = true;
      inherit package;
      host = "127.0.0.1";
      inherit port;
      dataDir = "/var/lib/jellything";
      logLevel = "info";
    };

    systemd.services.jellything = {
      after = ["jellyfin.service"];
      unitConfig.RequiresMountsFor = [jellyfinDataDir];
      serviceConfig = {
        ReadOnlyPaths = [jellyfinDataDir];
        SupplementaryGroups = ["jellyfin"];
      };
    };

    services.homelab.caddy.virtualHosts."jellything" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

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
    # Ferrofin writes reset files under data/, while Jellyfin uses its root.
    pinDirectory =
      if config.services.homelab.jellyfin.backend == "ferrofin"
      then "${jellyfinDataDir}/data"
      else jellyfinDataDir;
    package = inputs.inviterr.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
        inherit jellyfinDataDir;
        jellyfinUser = config.services.jellyfin.user;
        jellyfinGroup = config.services.jellyfin.group;
      };

      systemd.services.inviterr = {
        after = ["jellyfin.service"];
        unitConfig.RequiresMountsFor = [jellyfinDataDir];
        preStart = ''
          ${lib.getExe pkgs.python3} ${./configure.py} ${lib.escapeShellArg config.services.inviterr.configFile} ${lib.escapeShellArg pinDirectory}
        '';
      };

      systemd.tmpfiles.rules =
        lib.optional (config.services.homelab.jellyfin.backend == "ferrofin")
        "d ${pinDirectory} 0750 ${config.services.jellyfin.user} ${config.services.jellyfin.group} - -";

      services.homelab.caddy.virtualHosts."inviterr" = {
        inherit domain;
        public = true;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}

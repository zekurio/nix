{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.costthing;
    domain = "costs.${config.services.homelab.domains.schnitzelflix}";
    port = 8081;
    package = inputs.costthing.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in {
    options.services.homelab.costthing = {
      enable = lib.mkEnableOption "Jellyfin cost dashboard with Caddy integration";
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.jellyfin.enable;
          message = "services.homelab.costthing requires services.homelab.jellyfin.";
        }
      ];

      users = {
        groups.costthing = {};
        users.costthing = {
          isSystemUser = true;
          group = "costthing";
        };
      };

      systemd.services.costthing = {
        description = "Costthing Jellyfin cost dashboard";
        wantedBy = ["multi-user.target"];
        after = ["jellyfin.service"];
        wants = ["jellyfin.service"];
        environment = {
          PORT = toString port;
          JELLYFIN_URL = config.services.homelab.jellyfin.baseUrl;
          DATA_FILE = "/var/lib/costthing/costs.json";
        };
        serviceConfig = {
          ExecStart = lib.getExe package;
          User = "costthing";
          Group = "costthing";
          StateDirectory = "costthing";
          Restart = "on-failure";
          RestartSec = 5;

          CapabilityBoundingSet = "";
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
      };

      services.homelab.caddy.virtualHosts.costthing = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };

      # Same service published through the Pangolin edge. Both definitions can
      # coexist: whichever address the domain resolves to is the one serving,
      # so cutting over (or rolling back) is a DNS change.
      services.homelab.newt.resources.costthing = {
        displayName = "Costthing";
        inherit domain;
        target = "127.0.0.1:${toString port}";
      };
    };
  };
}

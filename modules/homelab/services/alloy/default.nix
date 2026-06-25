{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.alloy;
  domain = "clips.zekurio.me";
  port = 2552;
  storageDirs = {
    clips = "/tank/alloy/clips";
    thumbnails = "/var/lib/alloy/assets/thumbnails";
    users = "/var/lib/alloy/assets/users";
  };
in {
  imports = [
    inputs.alloy.nixosModules.default
  ];

  options.services.homelab.alloy = {
    enable = lib.mkEnableOption "Alloy self-hosted clip server";
  };

  config = lib.mkIf cfg.enable {
    services.alloy-server = {
      enable = true;
      inherit port;
      publicServerUrl = "https://${domain}";
      environmentFile = config.sops.secrets.alloy_env.path;

      storage.fs = {
        clipsPath = storageDirs.clips;
        thumbnailsPath = storageDirs.thumbnails;
        usersPath = storageDirs.users;
      };

      auth = {
        openRegistrations = true;
        requireAuthToBrowse = false;
      };

      limits.defaultStorageQuotaBytes = 16106127360;
    };

    systemd.tmpfiles.rules = let
      user = config.services.alloy-server.user;
      group = config.services.alloy-server.group;
    in [
      "d /tank/alloy 0750 ${user} ${group} - -"
      "d ${storageDirs.clips} 0750 ${user} ${group} - -"
      "d /var/lib/alloy/assets 0750 ${user} ${group} - -"
      "d ${storageDirs.thumbnails} 0750 ${user} ${group} - -"
      "d ${storageDirs.users} 0750 ${user} ${group} - -"
    ];

    systemd.services.alloy-storage-dirs = let
      user = config.services.alloy-server.user;
      group = config.services.alloy-server.group;
      dirs = [
        "/tank/alloy"
        storageDirs.clips
        "/var/lib/alloy/assets"
        storageDirs.thumbnails
        storageDirs.users
      ];
    in {
      description = "Create Alloy storage directories";
      requires = ["tank-datasets.service"];
      after = ["tank-datasets.service"];
      before = ["alloy-server.service"];
      path = [pkgs.coreutils];
      serviceConfig.Type = "oneshot";
      script = ''
        install -d -m 0750 -o ${lib.escapeShellArg user} -g ${lib.escapeShellArg group} ${lib.escapeShellArgs dirs}
      '';
    };

    systemd.services.alloy-server = {
      requires = ["alloy-storage-dirs.service"];
      after = ["alloy-storage-dirs.service"];
    };

    sops.secrets.alloy_env = {
      owner = config.services.alloy-server.user;
      group = config.services.alloy-server.group;
      mode = "0400";
    };

    services.homelab.caddy.virtualHosts."alloy" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

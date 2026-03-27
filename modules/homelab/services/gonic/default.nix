{
  config,
  lib,
  ...
}: let
  domain = "music.zekurio.xyz";
  port = 4747;
  musicDir = "/tank/media/music";
  dataDir = "/var/lib/gonic";
  cacheDir = "/var/cache/gonic";
  serviceUser = "gonic";
  serviceGroup = "gonic";
  shareGroup = "share";
in {
  options.services.homelab.gonic = {
    enable = lib.mkEnableOption "Gonic music server with Caddy integration";
  };

  config = lib.mkIf config.services.homelab.gonic.enable {
    users.groups.${serviceGroup} = {};

    users.users.${serviceUser} = {
      isSystemUser = true;
      group = serviceGroup;
      home = dataDir;
      createHome = true;
      extraGroups = [shareGroup];
      description = "Gonic music server";
    };

    services.gonic = {
      enable = true;
      settings = {
        listen-addr = "127.0.0.1:${toString port}";
        music-path = [musicDir];
        podcast-path = "${dataDir}/podcasts";
        playlists-path = "${dataDir}/playlists";
        cache-path = cacheDir;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir}/podcasts 2775 ${serviceUser} ${shareGroup} -"
      "d ${dataDir}/playlists 2775 ${serviceUser} ${shareGroup} -"
      "d ${cacheDir} 0750 ${serviceUser} ${serviceGroup} -"
    ];

    systemd.services.gonic.serviceConfig = {
      User = serviceUser;
      Group = serviceGroup;
      SupplementaryGroups = [shareGroup];
      UMask = lib.mkForce "0002";
    };

    services.homelab.caddy.virtualHosts."gonic" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
      extraConfig = "";
    };
  };
}

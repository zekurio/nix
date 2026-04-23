{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.navidrome;
  domain = "music.zekurio.xyz";
  port = 4533;
  musicDir = "/tank/media/music";
  dataDir = "/var/lib/navidrome";
in {
  options.services.homelab.navidrome = {
    enable = lib.mkEnableOption "Navidrome music server with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    services.navidrome = {
      enable = true;
      settings = {
        Address = "127.0.0.1";
        Port = port;
        MusicFolder = musicDir;
        DataFolder = dataDir;
        EnableInsightsCollector = false;
      };
    };

    users.users.navidrome.extraGroups = ["share"];

    systemd.services.navidrome.serviceConfig = {
      SupplementaryGroups = ["share"];
    };

    services.homelab.caddy.virtualHosts."navidrome" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

{
  config,
  lib,
  ...
}: let
  domain = "music.schnitzelflix.xyz";
  port = 4533;
  musicDir = "/tank/media/music";
in {
  options.services.homelab.navidrome = {
    enable = lib.mkEnableOption "Navidrome music streaming server with Caddy integration";
  };

  config = lib.mkIf config.services.homelab.navidrome.enable {
    services.navidrome = {
      enable = true;
      settings = {
        Address = "127.0.0.1";
        Port = port;
        MusicFolder = musicDir;
        EnableInsightsCollector = false;
        ScanSchedule = "1h";
      };
    };

    users.users.navidrome.extraGroups = ["share"];

    services.homelab.caddy.virtualHosts."navidrome" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
      extraConfig = "";
    };
  };
}

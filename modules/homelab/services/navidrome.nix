{
  config,
  lib,
  ...
}: let
  domain = "nv.zekurio.xyz";
  port = 4533;
in {
  options.services.navidrome-wrapped = {
    enable = lib.mkEnableOption "Navidrome music server with Caddy integration";
  };

  config = lib.mkIf config.services.navidrome-wrapped.enable {
    services.navidrome = {
      enable = true;
      settings = {
        Address = "127.0.0.1";
        Port = port;
        MusicFolder = "/tank/media/music";
      };
    };

    services.caddy-wrapper.virtualHosts."navidrome" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

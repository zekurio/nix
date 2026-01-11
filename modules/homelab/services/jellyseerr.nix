{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "requests.schnitzelflix.xyz";
  port = 5055;
in {
  options.services.jellyseerr-wrapped = {
    enable = lib.mkEnableOption "Jellyseerr media request manager with Caddy integration";
  };

  config = lib.mkIf config.services.jellyseerr-wrapped.enable {
    services.jellyseerr = {
      enable = true;
      port = port;
      openFirewall = true;
      package = pkgs.jellyseerr;
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."jellyseerr" = {
      domain = domain;
      reverseProxy = "localhost:${toString port}";
    };
  };
}

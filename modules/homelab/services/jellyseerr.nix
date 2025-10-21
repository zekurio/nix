{ config, lib, pkgs, ... }:

{
  options.services.jellyseerr-wrapped = {
    enable = lib.mkEnableOption "Jellyseerr media request manager with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "requests.schnitzelflix.xyz";
      description = "Domain name for Jellyseerr";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
      description = "Port for Jellyseerr to listen on";
    };
  };

  config = lib.mkIf config.services.jellyseerr-wrapped.enable {
    services.jellyseerr = {
      enable = true;
      port = config.services.jellyseerr-wrapped.port;
      openFirewall = true;
      package = pkgs.unstable.jellyseerr;
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."jellyseerr" = {
      domain = config.services.jellyseerr-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.jellyseerr-wrapped.port}";
    };
  };
}

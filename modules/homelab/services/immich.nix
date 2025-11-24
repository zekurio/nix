{ config
, lib
, pkgs
, ...
}: {
  options.services.immich-wrapped = {
    enable = lib.mkEnableOption "Immich photo management with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "photos.zekurio.xyz";
      description = "Domain name for Immich";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
      description = "Port for Immich to listen on";
    };
  };

  config = lib.mkIf config.services.immich-wrapped.enable {
    services.immich = {
      enable = true;
      host = "0.0.0.0";
      port = config.services.immich-wrapped.port;
      openFirewall = true;
      mediaLocation = "/tank/photos";
      package = pkgs.unstable.immich;
    };

    environment.systemPackages = [
      pkgs.unstable.immich-go
    ];

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."immich" = {
      domain = config.services.immich-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.immich-wrapped.port}";
    };

    users.users.immich.extraGroups = [ "share" "video" "render" ];
  };
}

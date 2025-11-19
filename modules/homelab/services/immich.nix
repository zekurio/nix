{ config
, lib
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
      host = "127.0.0.1";
      port = config.services.immich-wrapped.port;
      mediaLocation = "/tank/photos";
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."immich" = {
      domain = config.services.immich-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.immich-wrapped.port}";
    };

    users.users.immich.extraGroups = [ "share" "video" "render" ];

    # Ensure media directory exists
    systemd.tmpfiles.rules = [
      "d /tank/photos 0775 immich share -"
    ];
  };
}

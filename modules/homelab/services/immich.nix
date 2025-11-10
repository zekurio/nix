{
  config,
  lib,
  pkgs,
  ...
}: {
  options.services.immich-wrapped = {
    enable = lib.mkEnableOption "Immich photo management system with Caddy integration";
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
    mediaLocation = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/immich";
      description = "Location for Immich media files";
    };
  };

  config = lib.mkIf config.services.immich-wrapped.enable {
    services.immich = {
      enable = true;
      host = "127.0.0.1";
      openFirewall = true;
      port = config.services.immich-wrapped.port;
      package = pkgs.unstable.immich;
      mediaLocation = config.services.immich-wrapped.mediaLocation;
    };

    users.users.immich.extraGroups = [ "video" "render" ];

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."immich" = {
      domain = config.services.immich-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.immich-wrapped.port}";
    };
  };
}

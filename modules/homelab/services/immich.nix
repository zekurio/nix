{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "photos.zekurio.xyz";
  port = 2283;
in {
  options.services.immich-wrapped = {
    enable = lib.mkEnableOption "Immich photo management with Caddy integration";
  };

  config = lib.mkIf config.services.immich-wrapped.enable {
    services.immich = {
      enable = true;
      host = "0.0.0.0";
      port = port;
      openFirewall = true;
      mediaLocation = "/tank/immich";
      machine-learning.enable = true;
      accelerationDevices = ["/dev/dri/renderD128"];
      environment = {
        MACHINE_LEARNING_WORKERS = "1";
      };
    };

    environment.systemPackages = [
      pkgs.immich-go
    ];

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."immich" = {
      domain = domain;
      reverseProxy = "localhost:${toString port}";
    };

    users.users.immich.extraGroups = ["share" "video" "render"];
  };
}

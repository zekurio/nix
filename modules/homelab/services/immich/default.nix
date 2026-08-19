{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    domain = "photos.${config.services.homelab.domains.zekurio}";
    port = 2283;
  in {
    options.services.homelab.immich = {
      enable = lib.mkEnableOption "Immich photo management with Caddy integration";
    };

    config = lib.mkIf config.services.homelab.immich.enable {
      services.immich = {
        enable = true;
        # Loopback-only: external access goes through the public Caddy vhost.
        host = "127.0.0.1";
        port = port;
        openFirewall = false;
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
      services.homelab.caddy.virtualHosts."immich" = {
        domain = domain;
        public = true;
        reverseProxy = "127.0.0.1:${toString port}";
      };

      users.users.immich.extraGroups = [
        "share"
        "video"
        "render"
      ];
    };
  };
}

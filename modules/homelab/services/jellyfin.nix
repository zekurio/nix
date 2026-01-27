{
  config,
  lib,
  pkgs,
  ...
}: let
  shareUmask = "0002";
  domain = "schnitzelflix.xyz";
  port = 8096;
  serviceUser = "jellyfin";
  serviceGroup = "jellyfin";
in {
  options.services.jellyfin-wrapped = {
    enable = lib.mkEnableOption "Jellyfin media server with Caddy integration";
  };

  config = lib.mkIf config.services.jellyfin-wrapped.enable {
    services.jellyfin = {
      enable = true;
      openFirewall = true;
      dataDir = "/var/lib/jellyfin";
      cacheDir = "/var/cache/jellyfin";
    };

    environment.systemPackages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
    ];

    systemd.tmpfiles.rules = [
      "d /var/cache/jellyfin 2775 ${serviceUser} ${serviceGroup} -"
    ];

    systemd.services.jellyfin = {
      environment = {
        LIBVA_DRIVER_NAME = "iHD";
      };
      serviceConfig = {
        UMask = lib.mkForce shareUmask;
        ReadWritePaths = [
          "/var/cache/jellyfin"
          "/var/lib/jellyfin"
        ];
      };
    };

    users.users.jellyfin.extraGroups = [
      "render"
      "video"
    ];

    services.caddy-wrapper.virtualHosts."jellyfin" = {
      domain = domain;
      reverseProxy = "127.0.0.1:${toString port}";
      extraConfig = "";
    };
  };
}

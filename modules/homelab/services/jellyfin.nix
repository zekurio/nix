{
  config,
  lib,
  pkgs,
  ...
}: let
  shareUser = "share";
  shareGroup = "share";
  shareUmask = "0002";
  domain = "schnitzelflix.xyz";
  port = 8096;
in {
  options.services.jellyfin-wrapped = {
    enable = lib.mkEnableOption "Jellyfin media server with Caddy integration";
  };

  config = lib.mkIf config.services.jellyfin-wrapped.enable {
    services.jellyfin = {
      enable = true;
      user = shareUser;
      group = shareGroup;
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
      "d /var/cache/jellyfin 2775 ${shareUser} ${shareGroup} -"
    ];

    systemd.services.jellyfin = {
      serviceConfig = {
        UMask = lib.mkForce shareUmask;
        ReadWritePaths = [
          "/var/cache/jellyfin"
          "/var/lib/jellyfin"
        ];
      };
    };

    services.caddy-wrapper.virtualHosts."jellyfin" = {
      domain = domain;
      reverseProxy = "localhost:${toString port}";
      extraConfig = ''
      '';
    };
  };
}

{ config
, lib
, pkgs
, ...
}:
let
  mediaShare = config.modules.homelab.mediaShare;
  shareUser = mediaShare.user;
  shareGroup = mediaShare.group;
in
{
  options.services.jellyfin-wrapped = {
    enable = lib.mkEnableOption "Jellyfin media server with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "schnitzelflix.xyz";
      description = "Domain name for Jellyfin";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8096;
      description = "Port for Jellyfin HTTP interface";
    };
  };

  config = lib.mkIf config.services.jellyfin-wrapped.enable {
    services.jellyfin = {
      enable = true;
      package = pkgs.jellyfin;
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
        UMask = lib.mkForce mediaShare.umask;
        ReadWritePaths = [
          "/var/cache/jellyfin"
          "/var/lib/jellyfin"
        ];
      };
    };

    services.caddy-wrapper.virtualHosts."jellyfin" = {
      domain = config.services.jellyfin-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.jellyfin-wrapped.port}";
    };
  };
}

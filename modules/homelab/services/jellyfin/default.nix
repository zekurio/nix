{
  config,
  lib,
  pkgs,
  ...
}: let
  mediaShare = config.services.homelab.mediaShare;
  # Matinee took media.zekurio.me. Apps and TVs store the server address
  # and mostly ignore redirects, so Jellyfin keeps serving on its old name
  # until everyone has moved over.
  domain = config.services.homelab.domains.schnitzelflix;
  port = 8096;
in {
  options.services.homelab.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin media server with Caddy integration";
    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString port}";
      description = "Internal URL other services use to reach the Jellyfin API.";
    };
  };

  config = lib.mkIf config.services.homelab.jellyfin.enable {
    services.jellyfin = {
      enable = true;
      # Native ports stay closed; external clients reach Jellyfin through
      # the public Caddy vhost on 443.
      openFirewall = false;
    };

    environment.systemPackages = [pkgs.jellyfin-ffmpeg];

    systemd.services.jellyfin = {
      environment = {
        LIBVA_DRIVER_NAME = "iHD";
      };
      serviceConfig.UMask = lib.mkForce mediaShare.umask;
    };

    users.users.jellyfin.extraGroups = [
      "render"
      "video"
    ];

    services.homelab.backup = {
      stopUnits = ["jellyfin.service"];
      # Downloaded artwork and info, and seek-bar previews. A metadata
      # refresh and the trickplay task bring them back.
      exclude = [
        "${config.services.jellyfin.dataDir}/metadata/"
        "${config.services.jellyfin.dataDir}/data/trickplay/"
      ];
    };

    services.homelab.caddy.virtualHosts.jellyfin = {
      inherit domain;
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    mediaShare = config.modules.homelab.mediaShare;
    domain = config.services.homelab.domains.schnitzelflix;
    port = config.services.homelab.jellyfin.port;
    serviceUser = "jellyfin";
    serviceGroup = "jellyfin";
  in {
    options.services.homelab.jellyfin = {
      enable = lib.mkEnableOption "Jellyfin media server with Caddy integration";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8096;
        description = "Local HTTP port Jellyfin listens on.";
      };
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString config.services.homelab.jellyfin.port}";
        description = "Internal URL other services use to reach the Jellyfin API.";
      };
      publicUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://${domain}";
        description = "Public URL users and external clients use to reach Jellyfin.";
      };
    };

    config = lib.mkIf config.services.homelab.jellyfin.enable {
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
          UMask = lib.mkForce mediaShare.umask;
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

      services.homelab.caddy.virtualHosts."jellyfin" = {
        domain = domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };

      services.homelab.newt.resources.jellyfin = {
        displayName = "Jellyfin";
        inherit domain;
        target = "127.0.0.1:${toString port}";
      };
    };
  };
}

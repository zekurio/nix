{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.sabnzbd;
    downloadsRoot = config.modules.homelab.mediaShare.downloadsRoot;
    domain = "sab.${config.services.homelab.domains.schnitzelflix}";
    port = 6789;
    serviceUser = "sabnzbd";
    serviceGroup = "sabnzbd";
    mediaShare = config.modules.homelab.mediaShare;
  in {
    options.services.homelab.sabnzbd = {
      enable = lib.mkEnableOption "SABnzbd Usenet downloader with Caddy integration";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString port}";
        description = "URL other services use to reach the SABnzbd API.";
      };
    };

    config = lib.mkIf cfg.enable {
      services.sabnzbd = {
        enable = true;
        user = serviceUser;
        group = serviceGroup;
        configFile = null;
        allowConfigWrite = true;
        settings = {
          misc = {
            host = "0.0.0.0";
            port = port;
            username = "";
            password = "";
            html_login = false;
            inet_exposure = "api+web (locally no auth)";
            complete_dir = "${downloadsRoot}/complete";
            download_dir = "${downloadsRoot}/incomplete";
            dirscan_dir = "/var/lib/sabnzbd/nzb";
          };

          categories = {
            lidarr = {
              name = "lidarr";
              dir = "${downloadsRoot}/complete/lidarr";
              pp = 3;
              priority = 0;
              newzbin = "";
              script = "None";
            };
            radarr = {
              name = "radarr";
              dir = "${downloadsRoot}/complete/radarr";
              pp = 3;
              priority = 0;
              newzbin = "";
              script = "None";
            };
            sonarr = {
              name = "sonarr";
              dir = "${downloadsRoot}/complete/sonarr";
              pp = 3;
              priority = 0;
              newzbin = "";
              script = "None";
            };
            manual = {
              name = "manual";
              dir = "${downloadsRoot}/complete/manual";
              pp = 3;
              priority = 0;
              newzbin = "";
              script = "None";
            };
          };
        };
      };

      systemd.services.sabnzbd.serviceConfig = {
        SupplementaryGroups = [mediaShare.group];
        UMask = lib.mkForce mediaShare.umask;
      };

      systemd.tmpfiles.rules = [
        "f /var/lib/sabnzbd/sabnzbd.ini 0600 ${serviceUser} ${serviceGroup} -"
      ];

      services.homelab.caddy.virtualHosts."sabnzbd" = {
        inherit domain;
        forwardAuth = config.services.homelab.oauth2-proxy.schnitzelflix.forwardAuthAddress;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}

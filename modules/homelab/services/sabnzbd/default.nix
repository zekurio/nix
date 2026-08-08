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
            bandwidth_max = "70M";
            bandwidth_perc = 100;
            # The Arr clients remove completed entries after a successful import.
            history_retention_option = "all";
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

      # Reset the history and traffic statistics once. Bump the marker name to
      # intentionally repeat the reset without affecting the queue or config.
      systemd.services.sabnzbd.preStart = lib.mkBefore ''
        resetMarker=/var/lib/sabnzbd/.history-stats-reset-v1
        if [ ! -e "$resetMarker" ]; then
          rm -f \
            /var/lib/sabnzbd/admin/history1.db \
            /var/lib/sabnzbd/admin/history1.db-shm \
            /var/lib/sabnzbd/admin/history1.db-wal \
            /var/lib/sabnzbd/admin/totals10.sab
          touch "$resetMarker"
        fi
      '';

      systemd.tmpfiles.rules = [
        "f /var/lib/sabnzbd/sabnzbd.ini 0600 ${serviceUser} ${serviceGroup} -"
      ];

      # Published through the edge as a whole domain so Caddy keeps the forward
      # auth gate and the bypass token that API clients such as nzb360 rely on;
      # SABnzbd's own web UI has no authentication.
      services.homelab.newt.caddyDomains = [domain];

      services.homelab.caddy.virtualHosts."sabnzbd" = {
        inherit domain;
        forwardAuth = config.services.homelab.oauth2-proxy.schnitzelflix.forwardAuthAddress;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}

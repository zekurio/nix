{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.sabnzbd;
    downloadsRoot = config.modules.homelab.mediaShare.downloadsRoot;
    domain = "admin.${config.services.homelab.domains.zekurio}";
    port = 6789;
    serviceUser = "sabnzbd";
    serviceGroup = "sabnzbd";
    mediaShare = config.modules.homelab.mediaShare;
  in {
    options.services.homelab.sabnzbd = {
      enable = lib.mkEnableOption "SABnzbd Usenet downloader with Caddy integration";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString port}/sabnzbd";
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
            username = "zekurio";
            password = "@admin_password@";
            html_login = true;
            inet_exposure = "api+web (auth needed)";
            # Served under a path prefix on the shared admin domain; url_base
            # prefixes every route including the API.
            url_base = "/sabnzbd";
            # DNS-rebinding protection: Caddy passes the original Host header
            # through, so whitelist the vhost name (direct IP access always
            # passes the check).
            host_whitelist = domain;
            complete_dir = "${downloadsRoot}/complete";
            download_dir = "${downloadsRoot}/incomplete";
            dirscan_dir = "/var/lib/sabnzbd/nzb";
          };

          categories = {
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
        secretValues."@admin_password@" = config.sops.secrets.admin_password.path;
      };

      systemd.services.sabnzbd.serviceConfig = {
        SupplementaryGroups = [
          mediaShare.group
          config.sops.secrets.admin_password.group
        ];
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

      # LAN/tailnet-only vhost with SABnzbd's own login in front. url_base
      # makes SABnzbd handle the prefix itself, so no stripping here.
      services.homelab.caddy.virtualHosts."sabnzbd" = {
        inherit domain;
        extraConfig = ''
          redir /sabnzbd /sabnzbd/
          @sabnzbd path /sabnzbd*
          reverse_proxy @sabnzbd 127.0.0.1:${toString port}
        '';
      };
    };
  };
}

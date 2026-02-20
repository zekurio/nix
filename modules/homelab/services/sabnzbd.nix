{
  config,
  lib,
  ...
}: let
  cfg = config.services.sabnzbd-wrapped;
  domain = "sab.schnitzelflix.xyz";
  port = 6789;
  serviceUser = "sabnzbd";
  serviceGroup = "sabnzbd";
  shareUmask = "0002";
in {
  options.services.sabnzbd-wrapped = {
    enable = lib.mkEnableOption "SABnzbd Usenet downloader with Caddy integration";
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
          complete_dir = "/mnt/downloads/complete";
          download_dir = "/mnt/downloads/incomplete";
          dirscan_dir = "/var/lib/sabnzbd/nzb";
        };

        categories = {
          radarr = {
            name = "radarr";
            dir = "/mnt/downloads/complete/radarr";
            pp = 3;
            priority = 0;
            newzbin = "";
            script = "None";
          };
          sonarr = {
            name = "sonarr";
            dir = "/mnt/downloads/complete/sonarr";
            pp = 3;
            priority = 0;
            newzbin = "";
            script = "None";
          };
          manual = {
            name = "manual";
            dir = "/mnt/downloads/complete/manual";
            pp = 3;
            priority = 0;
            newzbin = "";
            script = "None";
          };
        };
      };
    };

    systemd.services.sabnzbd.serviceConfig = {
      UMask = lib.mkForce shareUmask;
    };

    systemd.tmpfiles.rules = [
      "f /var/lib/sabnzbd/sabnzbd.ini 0600 ${serviceUser} ${serviceGroup} -"
    ];

    services.caddy-wrapper.virtualHosts."sabnzbd" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4180";
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

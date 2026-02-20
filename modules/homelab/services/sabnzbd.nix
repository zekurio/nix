{
  config,
  lib,
  ...
}:
let
  cfg = config.services.sabnzbd-wrapped;
  domain = "nzb.schnitzelflix.xyz";
  port = 6789;
  serviceUser = "sabnzbd";
  serviceGroup = "sabnzbd";
in
{
  options.services.sabnzbd-wrapped = {
    enable = lib.mkEnableOption "SABnzbd Usenet downloader with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.nzbget_server1_host = {
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
    };
    sops.secrets.nzbget_server1_username = {
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
    };
    sops.secrets.nzbget_server1_password = {
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
    };

    sops.templates.sabnzbd_server_ini = {
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
      content = ''
        [servers]
        [[eweka]]
        host=${config.sops.placeholder.nzbget_server1_host}
        username=${config.sops.placeholder.nzbget_server1_username}
        password=${config.sops.placeholder.nzbget_server1_password}
      '';
    };

    services.sabnzbd = {
      enable = true;
      user = serviceUser;
      group = serviceGroup;
      configFile = null;
      allowConfigWrite = false;
      secretFiles = [ config.sops.templates.sabnzbd_server_ini.path ];
      settings = {
        misc = {
          host = "0.0.0.0";
          port = port;
          username = "admin";
          password = "rnt!KPV_zuc_jcq6fnx";
          html_login = false;
          inet_exposure = "api+web (locally no auth)";
          complete_dir = "/mnt/downloads/complete";
          download_dir = "/mnt/downloads/incomplete";
          dirscan_dir = "/var/lib/sabnzbd/nzb";
        };

        servers.eweka = {
          name = "eweka";
          displayname = "eweka";
          host = "placeholder.invalid";
          port = 563;
          ssl = true;
          ssl_verify = "strict";
          connections = 12;
          priority = 0;
          optional = false;
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

    services.caddy-wrapper.virtualHosts."sabnzbd" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4180";
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

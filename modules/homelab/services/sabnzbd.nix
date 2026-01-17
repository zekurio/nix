{
  config,
  lib,
  ...
}: let
  shareUser = "share";
  shareGroup = "share";
  domain = "sab.schnitzelflix.xyz";
  port = 8081;
in {
  options.services.sabnzbd-wrapped = {
    enable = lib.mkEnableOption "SABnzbd Usenet downloader with Caddy integration";
  };

  config = lib.mkIf config.services.sabnzbd-wrapped.enable {
    services.sabnzbd = {
      enable = true;
      user = shareUser;
      group = shareGroup;
      allowConfigWrite = true;
      settings.misc = {
        port = port;
        host = "127.0.0.1";
        host_whitelist = domain;
        # Permissions for completed downloads
        permissions = "775";
        # Download directories
        download_dir = "/mnt/downloads/incomplete";
        complete_dir = "/mnt/downloads/complete";
      };
    };

    # Ensure media-share directories and user exist before sabnzbd starts
    systemd.services.sabnzbd = {
      after = ["media-share-prepare.service"];
      requires = ["media-share-prepare.service"];
    };

    services.caddy-wrapper.virtualHosts."sabnzbd" = {
      domain = domain;
      extraConfig = ''
        reverse_proxy localhost:${toString port}
      '';
    };
  };
}

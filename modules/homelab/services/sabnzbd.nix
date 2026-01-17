{
  config,
  lib,
  ...
}: let
  shareUser = "share";
  shareGroup = "share";
  shareUmask = "0002";
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
      settings.misc = {
        port = port;
        host = "127.0.0.1";
        host_whitelist = domain;
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/sabnzbd 2775 ${shareUser} ${shareGroup} -"
    ];

    systemd.services.sabnzbd.serviceConfig = {
      UMask = lib.mkForce shareUmask;
      ReadWritePaths = ["/var/lib/sabnzbd"];
    };

    services.caddy-wrapper.virtualHosts."sabnzbd" = {
      domain = domain;
      extraConfig = ''
        reverse_proxy localhost:${toString port}
      '';
    };
  };
}

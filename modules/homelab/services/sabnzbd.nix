{
  config,
  lib,
  ...
}: let
  shareUser = "share";
  shareGroup = "share";
  shareUmask = "0002";
  domain = "sab.schnitzelflix.xyz";
  port = 8080;
in {
  options.services.sabnzbd-wrapped = {
    enable = lib.mkEnableOption "SABnzbd Usenet downloader with Caddy integration";
  };

  config = lib.mkIf config.services.sabnzbd-wrapped.enable {
    services.sabnzbd = {
      enable = true;
      user = shareUser;
      group = shareGroup;
    };

    systemd.services.sabnzbd.serviceConfig = {
      User = shareUser;
      Group = shareGroup;
      UMask = lib.mkForce shareUmask;
    };

    services.caddy-wrapper.virtualHosts."sabnzbd" = {
      domain = domain;
      extraConfig = ''
        reverse_proxy localhost:${toString port}
      '';
    };
  };
}

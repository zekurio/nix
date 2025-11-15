{ config
, lib
, ...
}:
let
  mediaShare = config.modules.homelab.mediaShare;
  shareUser = mediaShare.user;
  shareGroup = mediaShare.group;
in
{
  options.services.sabnzbd-wrapped = {
    enable = lib.mkEnableOption "SABnzbd Usenet downloader with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "sab.schnitzelflix.xyz";
      description = "Domain name for SABnzbd";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for SABnzbd to listen on";
    };
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
      UMask = lib.mkForce mediaShare.umask;
    };

    services.caddy-wrapper.virtualHosts."sabnzbd" = {
      domain = config.services.sabnzbd-wrapped.domain;
      extraConfig = ''
        reverse_proxy localhost:${toString config.services.sabnzbd-wrapped.port}
      '';
    };
  };
}

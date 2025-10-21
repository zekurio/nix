{ config, lib, ... }:

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
      group = "media";
    };

    users.users.sabnzbd = {
      group = "media";
    };

    systemd.services.sabnzbd.serviceConfig = {
      UMask = lib.mkForce "0002";
    };

    services.caddy-wrapper.virtualHosts."sabnzbd" = {
      domain = config.services.sabnzbd-wrapped.domain;
      extraConfig = ''
        reverse_proxy localhost:${toString config.services.sabnzbd-wrapped.port}
      '';
    };
  };
}

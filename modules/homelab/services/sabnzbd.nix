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
    };

    # Add sabnzbd user to media group
    users.users.sabnzbd.extraGroups = [ "media" ];

    # Allow SABnzbd to access shared media and downloads directories
    systemd.services.sabnzbd.serviceConfig = {
      SupplementaryGroups = [ "media" ];
      UMask = lib.mkForce "0002";
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."sabnzbd" = {
      domain = config.services.sabnzbd-wrapped.domain;
      extraConfig = ''
        reverse_proxy localhost:${toString config.services.sabnzbd-wrapped.port}
      '';
    };
  };
}

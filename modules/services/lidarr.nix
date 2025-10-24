{ config, lib, ... }:

let
  shareUser = "share";
  shareGroup = "share";
in
{
  options.services.lidarr-wrapped = {
    enable = lib.mkEnableOption "Lidarr music manager with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "arr.schnitzelflix.xyz";
      description = "Domain name for Lidarr";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8686;
      description = "Port for Lidarr to listen on";
    };
    musicFolder = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/fast-nvme/media/music";
      description = "Path to music library folder";
    };
  };

  config = lib.mkIf config.services.lidarr-wrapped.enable {
    services.lidarr = {
      enable = true;
      user = shareUser;
      group = shareGroup;
    };

    # Ensure Lidarr can access shared media library through group permissions
    systemd.services.lidarr.serviceConfig = {
      User = shareUser;
      Group = shareGroup;
      UMask = lib.mkForce "0002";
    };

    # Caddy virtual host configuration with base URL
    services.caddy-wrapper.virtualHosts."lidarr" = {
      domain = config.services.lidarr-wrapped.domain;
      extraConfig = ''
        redir /lidarr /lidarr/
        @lidarr path /lidarr*
        reverse_proxy @lidarr localhost:${toString config.services.lidarr-wrapped.port} {
          header_up Host {http.request.host}
          header_up X-Forwarded-Prefix /lidarr
        }
      '';
    };
  };
}

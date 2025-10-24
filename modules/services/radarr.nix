{ config, lib, ... }:

let
  shareUser = "share";
  shareGroup = "share";
in
{
  options.services.radarr-wrapped = {
    enable = lib.mkEnableOption "Radarr movie manager with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "arr.schnitzelflix.xyz";
      description = "Domain name for Radarr";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 7878;
      description = "Port for Radarr to listen on";
    };
  };

  config = lib.mkIf config.services.radarr-wrapped.enable {
    services.radarr = {
      enable = true;
      user = shareUser;
      group = shareGroup;
    };

    # Set umask for shared library access
    systemd.services.radarr.serviceConfig = {
      User = shareUser;
      Group = shareGroup;
      UMask = lib.mkForce "0002";
    };

    # Caddy virtual host configuration with base URL
    services.caddy-wrapper.virtualHosts."radarr" = {
      domain = config.services.radarr-wrapped.domain;
      extraConfig = ''
        redir /radarr /radarr/
        @radarr path /radarr*
        reverse_proxy @radarr localhost:${toString config.services.radarr-wrapped.port} {
          header_up Host {http.request.host}
          header_up X-Forwarded-Prefix /radarr
        }
      '';
    };
  };
}

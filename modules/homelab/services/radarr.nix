{
  config,
  lib,
  pkgs,
  ...
}: let
  shareUser = "share";
  shareGroup = "share";
  shareUmask = "0002";
  domain = "arr.schnitzelflix.xyz";
  port = 7878;
in {
  options.services.radarr-wrapped = {
    enable = lib.mkEnableOption "Radarr movie manager with Caddy integration";
  };

  config = lib.mkIf config.services.radarr-wrapped.enable {
    services.radarr = {
      enable = true;
      user = shareUser;
      group = shareGroup;
      settings = {
        server.urlBase = "/radarr";
      };
    };

    # Set umask for shared library access
    systemd.services.radarr.serviceConfig = {
      User = shareUser;
      Group = shareGroup;
      UMask = lib.mkForce shareUmask;
    };

    # Caddy virtual host configuration with base URL
    services.caddy-wrapper.virtualHosts."radarr" = {
      inherit domain;
      extraConfig = ''
        redir /radarr /radarr/
        @radarr path /radarr*
        reverse_proxy @radarr 127.0.0.1:${toString port} {
          header_up Host {http.request.host}
          header_up X-Forwarded-Prefix /radarr
        }
      '';
    };
  };
}

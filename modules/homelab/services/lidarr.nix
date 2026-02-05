{
  config,
  lib,
  ...
}: let
  shareUmask = "0002";
  domain = "arr.schnitzelflix.xyz";
  port = 8686;
in {
  options.services.lidarr-wrapped = {
    enable = lib.mkEnableOption "Lidarr music manager with Caddy integration";
  };

  config = lib.mkIf config.services.lidarr-wrapped.enable {
    services.lidarr = {
      enable = true;
      settings = {
        server.urlBase = "/lidarr";
      };
    };

    # Set umask for shared library access
    systemd.services.lidarr.serviceConfig = {
      UMask = lib.mkForce shareUmask;
    };

    # Caddy virtual host configuration with base URL
    services.caddy-wrapper.virtualHosts."lidarr" = {
      inherit domain;
      extraConfig = ''
        redir /lidarr /lidarr/
        @lidarr path /lidarr*
        reverse_proxy @lidarr 127.0.0.1:${toString port} {
          header_up Host {http.request.host}
          header_up X-Forwarded-Prefix /lidarr
        }
      '';
    };
  };
}

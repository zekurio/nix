{
  config,
  lib,
  ...
}: let
  shareUmask = "0002";
  domain = "arr.schnitzelflix.xyz";
  port = 7878;
in {
  options.services.homelab.radarr = {
    enable = lib.mkEnableOption "Radarr movie manager with Caddy integration";
  };

  config = lib.mkIf config.services.homelab.radarr.enable {
    services.radarr = {
      enable = true;
      settings = {
        server.urlBase = "/radarr";
        # delegate auth to the Caddy / Pocket ID forward-auth layer
        auth.method = "External";
      };
    };

    # Set umask for shared library access
    systemd.services.radarr.serviceConfig = {
      SupplementaryGroups = ["share"];
      UMask = lib.mkForce shareUmask;
    };

    # Caddy virtual host configuration with base URL
    services.homelab.caddy.virtualHosts."radarr" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4180";
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

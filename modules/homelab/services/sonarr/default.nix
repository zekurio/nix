{
  config,
  lib,
  pkgs,
  ...
}: let
  shareUmask = "0002";
  domain = "arr.schnitzelflix.xyz";
  port = 8989;
in {
  options.services.homelab.sonarr = {
    enable = lib.mkEnableOption "Sonarr TV show manager with Caddy integration";
  };

  config = lib.mkIf config.services.homelab.sonarr.enable {
    services.sonarr = {
      enable = true;
      settings = {
        server.urlBase = "/sonarr";
        # delegate auth to the Caddy / Pocket ID forward-auth layer
        auth.method = "External";
      };
    };

    systemd.services.sonarr.serviceConfig = {
      SupplementaryGroups = ["share"];
      UMask = lib.mkForce shareUmask;
    };

    # Caddy virtual host configuration with base URL
    services.homelab.caddy.virtualHosts."sonarr" = {
      domain = domain;
      forwardAuth = "127.0.0.1:4180";
      extraConfig = ''
        redir /sonarr /sonarr/
        @sonarr path /sonarr*
        reverse_proxy @sonarr 127.0.0.1:${toString port} {
          header_up Host {http.request.host}
          header_up X-Forwarded-Prefix /sonarr
        }
      '';
    };
  };
}

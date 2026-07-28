{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    mediaShare = config.modules.homelab.mediaShare;
    domain = "arr.${config.services.homelab.domains.schnitzelflix}";
    port = 8989;
  in {
    options.services.homelab.sonarr = {
      enable = lib.mkEnableOption "Sonarr TV show manager with Caddy integration";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString port}/sonarr";
        description = "URL other services use to reach the Sonarr API.";
      };
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
        SupplementaryGroups = [mediaShare.group];
        UMask = lib.mkForce mediaShare.umask;
      };

      # Caddy virtual host configuration with base URL
      # Caddy splits this domain across the arr services by path, which a
      # Pangolin resource cannot express, so the whole domain goes through
      # the edge with Caddy still routing and authenticating behind it.
      services.homelab.newt.caddyDomains = [domain];

      services.homelab.caddy.virtualHosts."sonarr" = {
        domain = domain;
        forwardAuth = config.services.homelab.oauth2-proxy.schnitzelflix.forwardAuthAddress;
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
  };
}

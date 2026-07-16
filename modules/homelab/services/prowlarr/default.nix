{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    domain = "arr.${config.services.homelab.domains.schnitzelflix}";
    port = 9696;
  in {
    options.services.homelab.prowlarr = {
      enable = lib.mkEnableOption "Prowlarr indexer manager with Caddy integration";
    };

    config = lib.mkIf config.services.homelab.prowlarr.enable {
      services.prowlarr = {
        enable = true;
        settings = {
          server.urlBase = "/prowlarr";
          # delegate auth to the Caddy / Pocket ID forward-auth layer
          auth.method = "External";
        };
      };

      # Caddy virtual host configuration with base URL
      services.homelab.caddy.virtualHosts."prowlarr" = {
        inherit domain;
        forwardAuth = config.services.homelab.oauth2-proxy.schnitzelflix.forwardAuthAddress;
        extraConfig = ''
          redir /prowlarr /prowlarr/
          @prowlarr path /prowlarr*
          reverse_proxy @prowlarr 127.0.0.1:${toString port} {
            header_up Host {http.request.host}
            header_up X-Forwarded-Prefix /prowlarr
          }
        '';
      };
    };
  };
}

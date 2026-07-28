{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    mediaShare = config.modules.homelab.mediaShare;
    domain = "music.${config.services.homelab.domains.zekurio}";
    port = 8686;
  in {
    options.services.homelab.lidarr = {
      enable = lib.mkEnableOption "Lidarr music manager with Caddy integration";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString port}/lidarr";
        description = "URL other services use to reach the Lidarr API.";
      };
    };

    config = lib.mkIf config.services.homelab.lidarr.enable {
      services.lidarr = {
        enable = true;
        settings = {
          server.urlBase = "/lidarr";
          # delegate auth to the Caddy / Pocket ID forward-auth layer
          auth.method = "External";
          # The package is built from the develop line (see
          # modules/nixpkgs/overlays/lidarr). Leaving this at master would make
          # the update check compare against releases this build is not from.
          update.branch = "develop";
        };
      };

      # Set umask for shared library access
      systemd.services.lidarr.serviceConfig = {
        SupplementaryGroups = [mediaShare.group];
        UMask = lib.mkForce mediaShare.umask;
      };

      # Caddy virtual host configuration with base URL
      # Published through the edge as a whole domain; Caddy keeps gating
      # /lidarr* behind forward auth.
      services.homelab.newt.caddyDomains = [domain];

      services.homelab.caddy.virtualHosts."lidarr" = {
        inherit domain;
        # Gate only /lidarr*: Navidrome serves the root of this domain.
        forwardAuth = config.services.homelab.oauth2-proxy.zekurio.forwardAuthAddress;
        authPaths = ["/lidarr*"];
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
  };
}

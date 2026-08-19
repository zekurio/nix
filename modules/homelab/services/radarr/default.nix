{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    mediaShare = config.modules.homelab.mediaShare;
    domain = "arr.${config.services.homelab.domains.schnitzelflix}";
    port = 7878;
  in {
    options.services.homelab.radarr = {
      enable = lib.mkEnableOption "Radarr movie manager with Caddy integration";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString port}/radarr";
        description = "URL other services use to reach the Radarr API.";
      };
    };

    config = lib.mkIf config.services.homelab.radarr.enable {
      services.radarr = {
        enable = true;
        settings = {
          server.urlBase = "/radarr";
          # App-native login; the vhost is LAN/tailnet-only, so no forward
          # auth layer in front. Radarr prompts to create the admin user on
          # first visit when none exists yet.
          auth.method = "Forms";
        };
      };

      # Set umask for shared library access
      systemd.services.radarr.serviceConfig = {
        SupplementaryGroups = [mediaShare.group];
        UMask = lib.mkForce mediaShare.umask;
      };

      services.homelab.caddy.virtualHosts."radarr" = {
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
  };
}

{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    mediaShare = config.modules.homelab.mediaShare;
    domain = "admin.${config.services.homelab.domains.zekurio}";
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
          # App-native login is provisioned from the shared admin password;
          # the vhost is LAN/tailnet-only, so no forward auth layer in front.
          auth.method = "Forms";
        };
      };

      systemd.services.sonarr.serviceConfig = {
        SupplementaryGroups = [mediaShare.group];
        UMask = lib.mkForce mediaShare.umask;
      };

      services.homelab.caddy.virtualHosts."sonarr" = {
        domain = domain;
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

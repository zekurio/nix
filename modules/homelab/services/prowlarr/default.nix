{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    domain = "admin.${config.services.homelab.domains.zekurio}";
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
          # App-native login is provisioned from the shared admin password;
          # the vhost is LAN/tailnet-only, so no forward auth layer in front.
          auth.method = "Forms";
        };
      };

      services.homelab.caddy.virtualHosts."prowlarr" = {
        inherit domain;
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

{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "arr.schnitzelflix.xyz";
  port = 9696;
in {
  options.services.prowlarr-wrapped = {
    enable = lib.mkEnableOption "Prowlarr indexer manager with Caddy integration";
  };

  config = lib.mkIf config.services.prowlarr-wrapped.enable {
    users.users.prowlarr = {
      isSystemUser = true;
      group = "prowlarr";
    };
    users.groups.prowlarr = {};

    services.prowlarr = {
      enable = true;
    };

    # Caddy virtual host configuration with base URL
    services.caddy-wrapper.virtualHosts."prowlarr" = {
      inherit domain;
      extraConfig = ''
        redir /prowlarr /prowlarr/
        @prowlarr path /prowlarr*
        reverse_proxy @prowlarr localhost:${toString port} {
          header_up Host {http.request.host}
          header_up X-Forwarded-Prefix /prowlarr
        }
      '';
    };
  };
}

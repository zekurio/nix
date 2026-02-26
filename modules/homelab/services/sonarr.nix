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
  options.services.sonarr-wrapped = {
    enable = lib.mkEnableOption "Sonarr TV show manager with Caddy integration";
  };

  config = lib.mkIf config.services.sonarr-wrapped.enable {
    services.sonarr = let
      sqlite-3-50 = pkgs.sqlite.overrideAttrs (old: {
        version = "3.50.0";
        src = pkgs.fetchurl {
          url = "https://sqlite.org/2025/sqlite-autoconf-3500000.tar.gz";
          sha256 = "09w32b04wbh1d5zmriwla7a02r93nd6vf3xqycap92a3yajpdirv";
        };
        configureFlags = lib.filter (flag: !(lib.hasInfix "tcl" flag)) old.configureFlags;
      });
    in {
      enable = true;
      package = pkgs.sonarr.override {sqlite = sqlite-3-50;};
      settings = {
        server.urlBase = "/sonarr";
        # delegate auth to the Caddy / Pocket ID forward-auth layer
        auth.method = "External";
      };
    };

    systemd.services.sonarr.serviceConfig = {
      UMask = lib.mkForce shareUmask;
    };

    # Caddy virtual host configuration with base URL
    services.caddy-wrapper.virtualHosts."sonarr" = {
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

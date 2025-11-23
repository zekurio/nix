{ config
, lib
, pkgs
, ...
}:
let
  mediaShare = config.modules.homelab.mediaShare;
  shareUser = mediaShare.user;
  shareGroup = mediaShare.group;

  beets-with-plugins = pkgs.beets.override {
    pluginOverrides = {
      lyrics = { enable = true; };
    };
  };

  beet-share = pkgs.writeShellScriptBin "beet-share" ''
    exec /run/wrappers/bin/sudo -u ${shareUser} ${beets-with-plugins}/bin/beet "$@"
  '';
in
{
  options.services.lidarr-wrapped = {
    enable = lib.mkEnableOption "Lidarr music manager with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "arr.schnitzelflix.xyz";
      description = "Domain name for Lidarr";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8686;
      description = "Port for Lidarr to listen on";
    };
  };

  config = lib.mkIf config.services.lidarr-wrapped.enable {
    environment.systemPackages = [
      beets-with-plugins
      beet-share
      pkgs.streamrip
    ];

    services.lidarr = {
      enable = true;
      user = shareUser;
      group = shareGroup;
      package = pkgs.unstable.lidarr;
    };

    # Set umask for shared library access
    systemd.services.lidarr.serviceConfig = {
      User = shareUser;
      Group = shareGroup;
      UMask = lib.mkForce mediaShare.umask;
    };

    # Caddy virtual host configuration with base URL
    services.caddy-wrapper.virtualHosts."lidarr" = {
      domain = config.services.lidarr-wrapped.domain;
      extraConfig = ''
        redir /lidarr /lidarr/
        @lidarr path /lidarr*
        reverse_proxy @lidarr localhost:${toString config.services.lidarr-wrapped.port} {
          header_up Host {http.request.host}
          header_up X-Forwarded-Prefix /lidarr
        }
      '';
    };
  };
}

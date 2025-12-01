{
  config,
  lib,
  ...
}:
let
  mediaShare = config.modules.homelab.mediaShare;
  shareUser = mediaShare.user;
  shareGroup = mediaShare.group;
in
{
  options.services.autobrr-wrapped = {
    enable = lib.mkEnableOption "autobrr torrent automation tool with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "arr.schnitzelflix.xyz";
      description = "Domain name for autobrr";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 7474;
      description = "Port for autobrr to listen on";
    };
  };

  config = lib.mkIf config.services.autobrr-wrapped.enable {
    services.autobrr = {
      enable = true;
      secretFile = config.sops.secrets.autobrr_secret.path;
      settings = {
        host = "0.0.0.0";
        port = config.services.autobrr-wrapped.port;
        baseUrl = "/autobrr/";
        baseUrlModeLegacy = false;
        logLevel = "INFO";
        checkForUpdates = true;
      };
    };

    # SOPS secret for autobrr session secret
    sops.secrets.autobrr_secret = {
      owner = shareUser;
      group = shareGroup;
      mode = "0400";
    };

    services.caddy-wrapper.virtualHosts."autobrr" = {
      domain = config.services.autobrr-wrapped.domain;
      extraConfig = ''
        redir /autobrr /autobrr/
        @autobrr path /autobrr*
        reverse_proxy @autobrr localhost:${toString config.services.autobrr-wrapped.port} {
          header_up Host {http.request.host}
          header_up X-Forwarded-Prefix /autobrr
        }
      '';
    };
  };
}

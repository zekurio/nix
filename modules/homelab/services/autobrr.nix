{
  config,
  lib,
  ...
}: let
  shareUser = "share";
  shareGroup = "share";
  domain = "arr.schnitzelflix.xyz";
  oidcIssuer = "https://auth.zekurio.xyz";
  port = 7474;
in {
  options.services.autobrr-wrapped = {
    enable = lib.mkEnableOption "autobrr torrent automation tool with Caddy integration";
  };

  config = lib.mkIf config.services.autobrr-wrapped.enable {
    services.autobrr = {
      enable = true;
      secretFile = config.sops.secrets.autobrr_session_secret.path;
      settings = {
        host = "0.0.0.0";
        port = port;
        baseUrl = "/autobrr/";
        baseUrlModeLegacy = false;
        logLevel = "INFO";
        checkForUpdates = true;
        # OIDC configuration with Pocket ID
        oidcEnabled = true;
        oidcIssuer = oidcIssuer;
        oidcRedirectUrl = "https://${domain}/autobrr/api/auth/oidc/callback";
        oidcDisableBuiltInLogin = true;
      };
    };

    # Load environment file with OIDC credentials
    systemd.services.autobrr.serviceConfig.EnvironmentFile = config.sops.secrets.autobrr_oidc.path;

    sops.secrets = {
      # Session secret (just the raw secret value)
      autobrr_session_secret = {
        owner = shareUser;
        group = shareGroup;
        mode = "0400";
      };
      # OIDC credentials as environment variables
      autobrr_oidc = {
        owner = shareUser;
        group = shareGroup;
        mode = "0400";
      };
    };

    services.caddy-wrapper.virtualHosts."autobrr" = {
      domain = domain;
      extraConfig = ''
        redir /autobrr /autobrr/
        @autobrr path /autobrr*
        reverse_proxy @autobrr localhost:${toString port} {
          header_up Host {http.request.host}
          header_up X-Forwarded-Prefix /autobrr
        }
      '';
    };
  };
}

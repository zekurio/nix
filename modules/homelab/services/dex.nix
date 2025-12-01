{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.dex-wrapped = {
    enable = lib.mkEnableOption "Dex OIDC provider with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "auth.zekurio.xyz";
      description = "Primary domain name for Dex";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5556;
      description = "Port for Dex to listen on";
    };
  };

  config = lib.mkIf config.services.dex-wrapped.enable {
    services.dex = {
      enable = true;
      package = pkgs.dex-oidc;
      environmentFile = config.sops.secrets.dex_env.path;
      settings = {
        issuer = "https://${config.services.dex-wrapped.domain}";
        web = {
          http = "127.0.0.1:${toString config.services.dex-wrapped.port}";
        };
        storage = {
          type = "sqlite3";
          config.file = "/var/lib/dex/dex.db";
        };
        oauth2 = {
          skipApprovalScreen = true;
          alwaysShowLoginScreen = false;
        };
        # Google OIDC connector for family login
        connectors = [
          {
            type = "google";
            id = "google";
            name = "Google";
            config = {
              clientID = "$GOOGLE_CLIENT_ID";
              clientSecret = "$GOOGLE_CLIENT_SECRET";
              redirectURI = "https://${config.services.dex-wrapped.domain}/callback";
            };
          }
        ];
        # Static clients - applications that use Dex for authentication
        # All clients share the same secret (DEX_CLIENT_SECRET env var)
        staticClients = [
          {
            id = "zekurio-services";
            secret = "$DEX_CLIENT_SECRET";
            name = "services - zekurio.xyz";
            redirectURIs = [
              # Immich
              "https://photos.zekurio.xyz/auth/login"
              "https://photos.zekurio.xyz/user-settings"
              "https://photos.zekurio.xyz/api/oauth/mobile-redirect"
              "app.immich:///oauth-callback"
              "https://docs.zekurio.xyz/accounts/oidc/dex/login/callback/"
            ];
          }
          {
            id = "schnitzelflix-services";
            secret = "$DEX_CLIENT_SECRET";
            name = "services - schnitzelflix.xyz";
            redirectURIs = [
              "https://schnitzelflix.xyz/callback"
              "https://jellyfin.schnitzelflix.xyz/callback"
              "https://jellyseerr.schnitzelflix.xyz/callback"
              "https://arr.schnitzelflix.xyz/callback"
            ];
          }
        ];
      };
    };

    # Add envsubst step to expand environment variables in config
    # and ensure StateDirectory for SQLite database
    systemd.services.dex.serviceConfig = {
      StateDirectory = "dex";
      ExecStartPre = lib.mkAfter [
        "${pkgs.writeShellScript "dex-envsubst" ''
          ${pkgs.envsubst}/bin/envsubst -i /run/dex/config.yaml -o /run/dex/config.yaml
        ''}"
      ];
    };

    # SOPS secret for Dex environment file
    sops.secrets.dex_env = {
      mode = "0400";
    };

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."dex" = {
      domain = config.services.dex-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.dex-wrapped.port}";
    };
  };
}

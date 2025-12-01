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
              # Optional: restrict to specific Google Workspace domain
              # hostedDomains = [ "yourdomain.com" ];
            };
          }
        ];
        # Static clients - applications that use Dex for authentication
        staticClients = [
          {
            id = "$DEX_CLIENT_ID_ZEKURIO";
            secret = "$DEX_CLIENT_SECRET_ZEKURIO";
            name = "Zekurio Services";
            redirectURIs = [
              # Immich
              "https://photos.zekurio.xyz/auth/login"
              "https://photos.zekurio.xyz/user-settings"
              "https://photos.zekurio.xyz/api/oauth/mobile-redirect"
              "app.immich:///oauth-callback"
              # Future services
              "https://zekurio.xyz/callback"
              "https://vw.zekurio.xyz/callback"
              "https://docs.zekurio.xyz/callback"
            ];
          }
          {
            id = "$DEX_CLIENT_ID_SCHNITZELFLIX";
            secret = "$DEX_CLIENT_SECRET_SCHNITZELFLIX";
            name = "Schnitzelflix Services";
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

    # Ensure /var/lib/dex directory exists for SQLite database
    systemd.tmpfiles.rules = [
      "d /var/lib/dex 0750 root root -"
    ];

    # SOPS secret for Dex environment file
    # Required variables:
    #   GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
    #   GOOGLE_CLIENT_SECRET=GOCSPX-xxx
    #   DEX_CLIENT_ID_ZEKURIO=zekurio-services
    #   DEX_CLIENT_SECRET_ZEKURIO=<random-secret>
    #   DEX_CLIENT_ID_SCHNITZELFLIX=schnitzelflix-services
    #   DEX_CLIENT_SECRET_SCHNITZELFLIX=<random-secret>
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

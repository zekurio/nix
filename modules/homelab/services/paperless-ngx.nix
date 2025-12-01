{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.paperless-ngx-wrapped = {
    enable = lib.mkEnableOption "Paperless-ngx document management system with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "docs.zekurio.xyz";
      description = "Domain name for Paperless-ngx";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8010;
      description = "Port for Paperless-ngx to listen on";
    };
  };

  config = lib.mkIf config.services.paperless-ngx-wrapped.enable {
    services.paperless = {
      enable = true;
      dataDir = "/var/lib/paperless";
      consumptionDir = "/var/lib/paperless/consume";
      consumptionDirIsPublic = true;
      port = config.services.paperless-ngx-wrapped.port;
      address = "127.0.0.1";
      package = pkgs.paperless-ngx;
      settings = {
        PAPERLESS_URL = "https://${config.services.paperless-ngx-wrapped.domain}";
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_TIME_ZONE = "Europe/Vienna";
        PAPERLESS_ENABLE_COMPRESSION = true;
        PAPERLESS_TASK_WORKERS = 2;

        # OIDC Authentication via Dex
        PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
        PAPERLESS_SOCIALACCOUNT_PROVIDERS = builtins.toJSON {
          openid_connect = {
            APPS = [
              {
                provider_id = "dex";
                name = "Sign in with Google";
                client_id = "zekurio-services";
                secret = "$DEX_CLIENT_SECRET";
                settings = {
                  server_url = "https://auth.zekurio.xyz";
                };
              }
            ];
            OAUTH_PKCE_ENABLED = true;
          };
        };
      };
      environmentFile = config.sops.secrets.paperless_env.path;
    };

    # SOPS secret for Paperless environment
    # Required: DEX_CLIENT_SECRET=<same secret as dex>
    sops.secrets.paperless_env = {
      mode = "0400";
      owner = "paperless";
    };

    # Create consumption directory
    systemd.tmpfiles.rules = [
      "d /var/lib/paperless/consume 0770 paperless paperless -"
    ];

    # Caddy virtual host configuration
    services.caddy-wrapper.virtualHosts."paperless-ngx" = {
      domain = config.services.paperless-ngx-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.paperless-ngx-wrapped.port}";
    };

    # Add redirect URI to Dex client
    # Note: Ensure "https://docs.zekurio.xyz/accounts/oidc/dex/login/callback/"
    # is added to the Dex staticClients redirectURIs for zekurio-services
  };
}

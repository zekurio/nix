{
  config,
  lib,
  pkgs,
  ...
}:
let
  # OIDC provider config without the secret - secret is added via environment file
  oidcProviderConfig = {
    openid_connect = {
      OAUTH_PKCE_ENABLED = "true";
      APPS = [
        {
          provider_id = "dex";
          name = "Sign in with Google";
          client_id = "zekurio-services";
          secret = "@DEX_CLIENT_SECRET@";
          settings.server_url = "https://auth.zekurio.xyz";
        }
      ];
    };
  };
in
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
      package = pkgs.paperless-ngx;
      dataDir = "/var/lib/paperless";
      consumptionDir = "/var/lib/paperless/consume";
      consumptionDirIsPublic = true;
      port = config.services.paperless-ngx-wrapped.port;
      address = "127.0.0.1";
      settings = {
        PAPERLESS_URL = "https://${config.services.paperless-ngx-wrapped.domain}";
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_TIME_ZONE = "Europe/Vienna";
        PAPERLESS_ENABLE_COMPRESSION = true;
        PAPERLESS_TASK_WORKERS = 2;
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];

        # OIDC Authentication via Dex
        PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
      };
    };

    # SOPS secret for Paperless environment
    # Required: DEX_CLIENT_SECRET=<same secret as dex>
    sops.secrets.paperless_env = {
      mode = "0400";
    };

    # Generate environment file with OIDC provider config at runtime
    systemd.services.paperless-web.serviceConfig.ExecStartPre = lib.mkBefore [
      "+${pkgs.writeShellScript "paperless-env-setup" ''
        source ${config.sops.secrets.paperless_env.path}
        mkdir -p /run/paperless
        providerJson=${lib.escapeShellArg (builtins.toJSON oidcProviderConfig)}
        providerJson="''${providerJson//@DEX_CLIENT_SECRET@/$DEX_CLIENT_SECRET}"
        echo "PAPERLESS_SOCIALACCOUNT_PROVIDERS=$providerJson" > /run/paperless/env
        chown paperless:paperless /run/paperless/env
        chmod 400 /run/paperless/env
      ''}"
    ];

    systemd.services.paperless-web.serviceConfig.EnvironmentFile = lib.mkForce "/run/paperless/env";

    systemd.services.paperless-scheduler.serviceConfig.ExecStartPre = lib.mkBefore [
      "+${pkgs.writeShellScript "paperless-scheduler-env-setup" ''
        while [ ! -f /run/paperless/env ]; do sleep 0.1; done
      ''}"
    ];

    systemd.services.paperless-scheduler.serviceConfig.EnvironmentFile =
      lib.mkForce "/run/paperless/env";

    systemd.services.paperless-task-queue.serviceConfig.ExecStartPre = lib.mkBefore [
      "+${pkgs.writeShellScript "paperless-task-queue-env-setup" ''
        while [ ! -f /run/paperless/env ]; do sleep 0.1; done
      ''}"
    ];

    systemd.services.paperless-task-queue.serviceConfig.EnvironmentFile =
      lib.mkForce "/run/paperless/env";

    systemd.tmpfiles.rules = [
      "d /var/lib/paperless/consume 0770 paperless paperless -"
    ];

    services.caddy-wrapper.virtualHosts."paperless-ngx" = {
      domain = config.services.paperless-ngx-wrapped.domain;
      reverseProxy = "localhost:${toString config.services.paperless-ngx-wrapped.port}";
    };

    users.users.paperless.extraGroups = [ "share" ];
  };
}

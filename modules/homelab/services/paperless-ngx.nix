{ config, lib, pkgs, ... }:
let
  cfg = config.services.paperless-ngx-wrapped;
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

  config = lib.mkIf cfg.enable {
    services.paperless = {
      enable = true;
      package = pkgs.paperless-ngx;
      dataDir = "/var/lib/paperless";
      consumptionDir = "/var/lib/paperless/consume";
      consumptionDirIsPublic = true;
      port = cfg.port;
      address = "127.0.0.1";
      settings = {
        PAPERLESS_URL = "https://${cfg.domain}";
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
      # Environment file containing PAPERLESS_SOCIALACCOUNT_PROVIDERS JSON
      # See secrets/adam.yaml for the required format
      environmentFile = config.sops.secrets.paperless_env.path;
    };

    sops.secrets.paperless_env = {
      owner = "paperless";
      group = "paperless";
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/paperless/consume 0770 paperless paperless -"
    ];

    services.caddy-wrapper.virtualHosts."paperless-ngx" = {
      domain = cfg.domain;
      reverseProxy = "localhost:${toString cfg.port}";
    };

    users.users.paperless.extraGroups = [ "share" ];
  };
}

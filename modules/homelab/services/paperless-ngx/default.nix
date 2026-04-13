{
  config,
  lib,
  ...
}: let
  domain = "docs.zekurio.xyz";
  port = 8010;
in {
  options.services.homelab.paperless-ngx = {
    enable = lib.mkEnableOption "Paperless-ngx document management system with Caddy integration";
  };

  config = lib.mkIf config.services.homelab.paperless-ngx.enable {
    services.paperless = {
      enable = true;
      dataDir = "/var/lib/paperless";
      consumptionDir = "/var/lib/paperless/consume";
      consumptionDirIsPublic = true;
      port = port;
      address = "127.0.0.1";
      environmentFile = config.sops.secrets.paperless_env.path;
      settings = {
        PAPERLESS_URL = "https://${domain}";
        PAPERLESS_DISABLE_REGULAR_LOGIN = true;
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_TIME_ZONE = "Europe/Vienna";
        PAPERLESS_ENABLE_COMPRESSION = true;
        PAPERLESS_TASK_WORKERS = 2;
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/paperless/consume 0770 paperless paperless -"
    ];

    services.homelab.caddy.virtualHosts."paperless-ngx" = {
      domain = domain;
      reverseProxy = "127.0.0.1:${toString port}";
      extraConfig = ''
        @blocked path /admin/*
        respond @blocked "Forbidden" 403
      '';
    };

    users.users.paperless.extraGroups = ["share"];

    sops.secrets.paperless_env = {
      owner = "paperless";
      group = "paperless";
      mode = "0400";
    };
  };
}

{
  config,
  lib,
  ...
}: {
  options.services.paperless-ngx-wrapped = {
    enable = lib.mkEnableOption "Paperless-ngx document management system with Caddy integration";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "ppl.zekurio.xyz";
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
      settings = {
        PAPERLESS_URL = "https://${config.services.paperless-ngx-wrapped.domain}";
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_TIME_ZONE = "Europe/Berlin";
        PAPERLESS_ENABLE_COMPRESSION = true;
        PAPERLESS_TASK_WORKERS = 2;
      };
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
  };
}

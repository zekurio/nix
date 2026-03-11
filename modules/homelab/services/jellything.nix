{
  config,
  lib,
  ...
}: let
  cfg = config.services.jellything-wrapped;
  domain = cfg.domain;
  port = 3010;
  containerPort = 3000;
  appUrl = if cfg.appUrl == null then "https://${domain}" else cfg.appUrl;
  allowedHosts = lib.unique ([domain] ++ cfg.allowedHosts);
  containerUser = "0:0";
in {
  options.services.jellything-wrapped = {
    enable = lib.mkEnableOption "Jellything invite service with Caddy integration";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "jt.schnitzelflix.xyz";
      description = "Public domain served by Caddy for Jellything.";
    };

    appUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://jt.schnitzelflix.xyz";
      description = "Override the APP_URL passed to Jellything. Defaults to https://<domain>.";
    };

    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["other.example.com"];
      description = "Additional hostnames allowed by Jellything's Vite preview host check.";
    };

    disableHostCheck = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable Vite host checking for Jellything. Less safe than explicit allowed hosts.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.jellything = {
      image = "ghcr.io/zekurio/jellything:latest";
      user = containerUser;
      ports = ["${toString port}:${toString containerPort}"];
      environment = {
        NODE_ENV = "production";
        LOG_LEVEL = "debug";
        DB_PATH = "/app/data/jellything.db";
        CONFIG_FILE = "/app/config/config.json";
        APP_URL = appUrl;
      }
      // lib.optionalAttrs (!cfg.disableHostCheck) {
        ALLOWED_HOSTS = lib.concatStringsSep "," allowedHosts;
      }
      // lib.optionalAttrs cfg.disableHostCheck {
        DISABLE_HOST_CHECK = "true";
      };
      environmentFiles = [config.sops.secrets.jellything_env.path];
      volumes = [
        "jellything_data:/app/data"
        "jellything_config:/app/config"
        "/var/lib/jellyfin:/jf:ro"
      ];
    };

    sops.secrets.jellything_env = {};

    services.caddy-wrapper.virtualHosts."jellything" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

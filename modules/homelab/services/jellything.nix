{
  config,
  lib,
  ...
}: let
  cfg = config.services.jellything-wrapped;
  domain = "jt.schnitzelflix.xyz";
  port = 3010;
  containerPort = 3000;
  appUrl = "https://${domain}";
in {
  options.services.jellything-wrapped = {
    enable = lib.mkEnableOption "Jellything invite service with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.jellything = {
      image = "ghcr.io/zekurio/jellything:latest";
      ports = ["${toString port}:${toString containerPort}"];
      environment = {
        NODE_ENV = "production";
        LOG_LEVEL = "debug";
        DATABASE_URL = "/app/data/jellything.db";
        CONFIG_PATH = "/app/config/config.json";
        APP_URL = appUrl;
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

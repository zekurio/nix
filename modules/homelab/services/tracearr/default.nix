{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.tracearr;
  domain = "trace.schnitzelflix.xyz";
  port = 3000;
in {
  options.services.homelab.tracearr = {
    enable = lib.mkEnableOption "Tracearr stream analytics with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.tracearr = {
      image = "ghcr.io/connorgallopo/tracearr:supervised";
      ports = ["127.0.0.1:${toString port}:3000"];
      environment = {
        TZ = "Europe/Vienna";
        LOG_LEVEL = "info";
      };
      environmentFiles = [config.sops.secrets.tracearr_env.path];
      volumes = [
        "tracearr_postgres:/data/postgres"
        "tracearr_redis:/data/redis"
        "tracearr_data:/data/tracearr"
      ];
      extraOptions = [
        "--pull=newer"
        "--shm-size=512m"
        "--memory=3g"
        "--ulimit=nofile=65536:65536"
      ];
    };

    sops.secrets.tracearr_env = {
      mode = "0400";
    };

    services.homelab.caddy.virtualHosts."tracearr" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

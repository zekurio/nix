{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.tracearr;
  domain = "trace.schnitzelflix.xyz";
  port = 3000;
  stateDir = "/var/lib/tracearr";
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
        "${stateDir}/postgres:/data/postgres"
        "${stateDir}/redis:/data/redis"
        "${stateDir}/tracearr:/data/tracearr"
      ];
      extraOptions = [
        "--pull=newer"
        "--shm-size=512m"
        "--memory=3g"
        "--ulimit=nofile=65536:65536"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
      "d ${stateDir}/postgres 0755 root root -"
      "d ${stateDir}/redis 0755 root root -"
      "d ${stateDir}/tracearr 0755 root root -"
    ];

    sops.secrets.tracearr_env = {
      mode = "0400";
    };

    services.homelab.caddy.virtualHosts."tracearr" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

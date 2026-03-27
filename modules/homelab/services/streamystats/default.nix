{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.streamystats;
  domain = "stats.schnitzelflix.xyz";
  port = 3020;
  containerPort = 3000;
  dataDir = "/var/lib/streamystats";
in {
  options.services.homelab.streamystats = {
    enable = lib.mkEnableOption "Streamystats analytics service with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.streamystats = {
      image = "ghcr.io/fredrikburmester/streamystats-aio:latest";
      ports = ["127.0.0.1:${toString port}:${toString containerPort}"];
      environmentFiles = [config.sops.secrets.streamystats_env.path];
      volumes = [
        "${dataDir}/postgres:/var/lib/postgresql/data"
      ];
      extraOptions = [
        "--pull=newer"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0755 root root -"
      "d ${dataDir}/postgres 0755 root root -"
    ];

    sops.secrets.streamystats_env = {
      mode = "0400";
    };

    services.homelab.caddy.virtualHosts."streamystats" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

{
  config,
  lib,
  ...
}: let
  port = 3000;
  domain = "stats.schnitzelflix.xyz";
in {
  options.services.streamystats-wrapped = {
    enable = lib.mkEnableOption "StreamyStats Jellyfin analytics with Caddy integration";
  };

  config = lib.mkIf config.services.streamystats-wrapped.enable {
    virtualisation.oci-containers.containers.streamystats = {
      image = "docker.io/fredrikburmester/streamystats-v2-aio:latest";
      ports = ["${toString port}:3000"];
      environment = {
        POSTGRES_USER = "postgres";
        POSTGRES_PASSWORD = "postgres";
        POSTGRES_DB = "streamystats";
        DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/streamystats";
        NODE_ENV = "production";
      };
      environmentFiles = [config.sops.secrets.streamystats_env.path];
      volumes = ["streamystats_data:/var/lib/postgresql/data"];
      extraOptions = ["--network=homelab"];
    };

    systemd.services.podman-streamystats = {
      requires = ["podman-network-homelab.service"];
      after = ["podman-network-homelab.service"];
    };

    sops.secrets.streamystats_env = {};

    services.caddy-wrapper.virtualHosts."streamystats" = {
      domain = domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

{
  config,
  lib,
  ...
}: let
  port = 3002;
  domain = "sweep.schnitzelflix.xyz";
in {
  options.services.jellysweep-wrapped = {
    enable = lib.mkEnableOption "Jellysweep media cleanup tool with Caddy integration";
  };

  config = lib.mkIf config.services.jellysweep-wrapped.enable {
    virtualisation.oci-containers.containers.jellysweep = {
      image = "ghcr.io/jon4hz/jellysweep:latest";
      ports = ["${toString port}:3002"];
      environment = {
        JELLYSWEEP_LISTEN = "0.0.0.0:3002";
        JELLYSWEEP_DRY_RUN = "true";
        JELLYSWEEP_AUTH_JELLYFIN_ENABLED = "true";
        JELLYSWEEP_STREAMYSTATS_URL = "http://streamystats:3000";
      };
      environmentFiles = [config.sops.secrets.jellysweep_env.path];
      volumes = ["jellysweep_data:/app/data"];
      extraOptions = ["--network=homelab"];
    };

    sops.secrets.jellysweep_env = {};

    services.caddy-wrapper.virtualHosts."jellysweep" = {
      domain = domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

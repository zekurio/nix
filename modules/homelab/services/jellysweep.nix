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
    # Config file for jellysweep (library config cannot be set via env vars)
    environment.etc."jellysweep/config.yml".text = ''
      dry_run: false
      libraries:
        "Filme":
          enabled: true
          cleanup_delay: 60
          protection_period: 90
          filter:
            content_age_threshold: 90
            last_stream_threshold: 60
          disk_usage_thresholds:
            - usage_percent: 75.0
              max_cleanup_delay: 30
            - usage_percent: 85.0
              max_cleanup_delay: 14
            - usage_percent: 90.0
              max_cleanup_delay: 7
            - usage_percent: 95.0
              max_cleanup_delay: 2
        "Anime":
          enabled: true
          cleanup_delay: 60
          protection_period: 90
          filter:
            content_age_threshold: 90
            last_stream_threshold: 60
          disk_usage_thresholds:
            - usage_percent: 75.0
              max_cleanup_delay: 30
            - usage_percent: 85.0
              max_cleanup_delay: 14
            - usage_percent: 90.0
              max_cleanup_delay: 7
            - usage_percent: 95.0
              max_cleanup_delay: 2
        "Serien":
          enabled: true
          cleanup_delay: 60
          protection_period: 90
          filter:
            content_age_threshold: 90
            last_stream_threshold: 60
          disk_usage_thresholds:
            - usage_percent: 75.0
              max_cleanup_delay: 30
            - usage_percent: 85.0
              max_cleanup_delay: 14
            - usage_percent: 90.0
              max_cleanup_delay: 7
            - usage_percent: 95.0
              max_cleanup_delay: 2
    '';

    virtualisation.oci-containers.containers.jellysweep = {
      image = "ghcr.io/jon4hz/jellysweep:latest";
      environment = {
        JELLYSWEEP_LISTEN = "0.0.0.0:3002";
        JELLYSWEEP_AUTH_JELLYFIN_ENABLED = "true";
      };
      environmentFiles = [config.sops.secrets.jellysweep_env.path];
      volumes = [
        "jellysweep_data:/app/data"
        "/etc/jellysweep/config.yml:/app/config.yml:ro"
        "/tank/jellyfin:/tank/jellyfin:ro"
      ];
      extraOptions = ["--network=host"];
    };

    sops.secrets.jellysweep_env = {};

    services.caddy-wrapper.virtualHosts."jellysweep" = {
      domain = domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}

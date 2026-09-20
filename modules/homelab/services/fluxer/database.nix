{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
  in {
    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = ["d /var/lib/fluxer/postgres 0700 70 70 -"];
      virtualisation.oci-containers.containers.fluxer-postgres = {
        image = "docker.io/library/postgres:16-alpine";
        environment = {
          POSTGRES_DB = "fluxer";
          POSTGRES_USER = "fluxer";
        };
        environmentFiles = ["/run/fluxer-env/fluxer-postgres.env"];
        cmd = [
          "postgres"
          "-c"
          "max_connections=150"
          "-c"
          "shared_buffers=512MB"
          "-c"
          "effective_cache_size=2GB"
          "-c"
          "work_mem=8MB"
          "-c"
          "maintenance_work_mem=256MB"
          "-c"
          "autovacuum_work_mem=128MB"
          "-c"
          "random_page_cost=1.1"
          "-c"
          "effective_io_concurrency=200"
          "-c"
          "default_statistics_target=200"
          "-c"
          "jit=off"
          "-c"
          "min_wal_size=512MB"
          "-c"
          "max_wal_size=2GB"
          "-c"
          "checkpoint_completion_target=0.9"
          "-c"
          "wal_buffers=16MB"
          "-c"
          "wal_compression=zstd"
          "-c"
          "bgwriter_delay=50ms"
          "-c"
          "bgwriter_lru_maxpages=1000"
          "-c"
          "autovacuum_vacuum_scale_factor=0.05"
          "-c"
          "autovacuum_analyze_scale_factor=0.02"
          "-c"
          "autovacuum_vacuum_cost_limit=2000"
          "-c"
          "track_io_timing=on"
          "-c"
          "shared_preload_libraries=pg_stat_statements"
        ];
        volumes = ["/var/lib/fluxer/postgres:/var/lib/postgresql/data"];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=5368709120"
          "--memory-reservation=3221225472"
          "--shm-size=268435456"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=10"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "pg_isready"
              "-h"
              "127.0.0.1"
              "-U"
              "fluxer"
              "-d"
              "fluxer"
            ])
        ];
      };
    };
  };
}

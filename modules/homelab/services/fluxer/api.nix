{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
  in {
    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.fluxer-api = {
        image = "ghcr.io/fluxerapp/fluxer-api:${cfg.imageTag}";
        environment = {
          FLUXER_API_PORT = "8080";
          FLUXER_API_PRESIGNED_ATTACHMENT_UPLOADS_ENABLED = "true";
          FLUXER_POSTGRES_MAX_CONNECTIONS = "25";
          NODE_OPTIONS = "--enable-source-maps";
        };
        dependsOn = [
          "fluxer-gifs"
          "fluxer-gifs-shard"
          "fluxer-meilisearch"
          "fluxer-messages"
          "fluxer-messages-shard"
          "fluxer-nats"
          "fluxer-postgres"
          "fluxer-snowflakes"
          "fluxer-snowflakes-shard"
          "fluxer-users"
          "fluxer-users-shard"
          "fluxer-valkey"
        ];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=2684354560"
          "--memory-reservation=1073741824"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=30"
          "--health-start-period=1m30s"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "/bin/sh"
              "-c"
              "node -e \"fetch('http://127.0.0.1:8080/_health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""
            ])
        ];
      };
      systemd.services.podman-fluxer-api = {
        requires = ["fluxer-seaweedfs-init.service"];
        after = ["fluxer-seaweedfs-init.service"];
      };
      virtualisation.oci-containers.containers.fluxer-worker = {
        image = "ghcr.io/fluxerapp/fluxer-api:${cfg.imageTag}";
        environment = {
          FLUXER_API_WORKER_ENABLE_CRON_SCHEDULER = "true";
          FLUXER_API_WORKER_MODE = "all_lanes";
          FLUXER_POSTGRES_MAX_CONNECTIONS = "25";
          NODE_OPTIONS = "--enable-source-maps";
        };
        cmd = [
          "sh"
          "-c"
          "if [ -f dist/WorkerEntrypoint.js ]; then exec node dist/WorkerEntrypoint.js; else exec ./node_modules/.bin/tsx src/WorkerEntrypoint.ts; fi"
        ];
        workdir = "/usr/src/app/fluxer_api";
        dependsOn = [
          "fluxer-messages-shard"
          "fluxer-nats"
          "fluxer-postgres"
          "fluxer-snowflakes-shard"
          "fluxer-users-shard"
          "fluxer-valkey"
        ];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=2684354560"
          "--memory-reservation=1073741824"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=3"
          "--health-start-period=1m30s"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "node"
              "-e"
              "const age=Date.now()-require('node:fs').statSync('/tmp/fluxer-worker-heartbeat').mtimeMs;if(age>30000){console.error('worker heartbeat is '+Math.round(age)+'ms old');process.exit(1)}"
            ])
        ];
      };
      systemd.services.podman-fluxer-worker = {
        requires = ["fluxer-seaweedfs-init.service"];
        after = ["fluxer-seaweedfs-init.service"];
      };
    };
  };
}

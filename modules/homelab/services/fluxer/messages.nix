{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
  in {
    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.fluxer-messages = {
        image = "ghcr.io/fluxerapp/fluxer-messages:${cfg.imageTag}";
        environment = {
          FLUXER_SVC_MAX_CONCURRENT_REQUESTS = "";
          FLUXER_SVC_MODE = "router";
          FLUXER_SVC_NAME = "messages";
        };
        dependsOn = [
          "fluxer-nats"
        ];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=134217728"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=30"
          "--health-start-period=1m0s"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "bash"
              "-c"
              "exec 3<>/dev/tcp/127.0.0.1/8090 && printf 'GET /_health HTTP/1.0\\r\\n\\r\\n' >&3 && head -n 1 <&3 | grep -q ' 200 '"
            ])
        ];
      };
      virtualisation.oci-containers.containers.fluxer-messages-shard = {
        image = "ghcr.io/fluxerapp/fluxer-messages:${cfg.imageTag}";
        environment = {
          FLUXER_POSTGRES_MAX_CONNECTIONS = "20";
          FLUXER_SVC_MAX_CONCURRENT_REQUESTS = "";
          FLUXER_SVC_MODE = "shard";
          FLUXER_SVC_NAME = "messages";
          FLUXER_SVC_SHARD_ID = "0";
        };
        dependsOn = [
          "fluxer-nats"
          "fluxer-postgres"
        ];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=268435456"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=30"
          "--health-start-period=1m0s"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "bash"
              "-c"
              "exec 3<>/dev/tcp/127.0.0.1/8090 && printf 'GET /_health HTTP/1.0\\r\\n\\r\\n' >&3 && head -n 1 <&3 | grep -q ' 200 '"
            ])
        ];
      };
    };
  };
}

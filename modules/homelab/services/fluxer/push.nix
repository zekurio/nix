{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
  in {
    config = lib.mkIf cfg.enable {
      # The gateway only queues notifications. Without this container they
      # expire in its outbox, so neither web nor mobile push is delivered.
      virtualisation.oci-containers.containers.fluxer-push = {
        image = "ghcr.io/fluxerapp/fluxer-push:${cfg.imageTag}";
        dependsOn = [
          "fluxer-api"
          "fluxer-nats"
        ];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=268435456"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=30"
          "--health-start-period=1m"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "/usr/local/bin/fluxer-push"
              "healthcheck"
            ])
        ];
      };
    };
  };
}

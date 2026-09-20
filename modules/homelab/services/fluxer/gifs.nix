{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
    domain = "chat.${config.services.homelab.domains.zekurio}";
  in {
    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.fluxer-gifs = {
        image = "ghcr.io/fluxerapp/fluxer-gifs:${cfg.imageTag}";
        environment = {
          FLUXER_MEDIA_PROXY_PUBLIC_ENDPOINT = "https://${domain}/media";
          FLUXER_SVC_MODE = "router";
          FLUXER_SVC_NAME = "gifs";
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
      virtualisation.oci-containers.containers.fluxer-gifs-shard = {
        image = "ghcr.io/fluxerapp/fluxer-gifs:${cfg.imageTag}";
        environment = {
          FLUXER_MEDIA_PROXY_PUBLIC_ENDPOINT = "https://${domain}/media";
          FLUXER_SVC_MODE = "shard";
          FLUXER_SVC_NAME = "gifs";
          FLUXER_SVC_SHARD_ID = "0";
        };
        dependsOn = [
          "fluxer-nats"
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

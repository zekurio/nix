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
      virtualisation.oci-containers.containers.fluxer-gateway = {
        image = "ghcr.io/fluxerapp/fluxer-gateway:${cfg.imageTag}";
        environment = {
          FLUXER_ERLANG_SCHEDULERS_MAX = "16";
          FLUXER_ERLANG_SCHEDULERS_MIN = "2";
          FLUXER_GATEWAY_LOGGER_LEVEL = "info";
          FLUXER_GATEWAY_MEDIA_PROXY_ENDPOINT = "https://${domain}/media";
          FLUXER_GATEWAY_PORT = "8080";
          FLUXER_GATEWAY_STATIC_CDN_ENDPOINT = "https://${domain}";
        };
        environmentFiles = ["/run/fluxer-env/fluxer-gateway.env"];
        dependsOn = [
          "fluxer-nats"
          "fluxer-valkey"
        ];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=1073741824"
          "--memory-reservation=402653184"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=30"
          "--health-start-period=1m30s"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "curl"
              "-fsS"
              "-o"
              "/dev/null"
              "http://127.0.0.1:8080/_health/ready"
            ])
        ];
      };
    };
  };
}

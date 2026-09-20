{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
  in {
    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = ["d /var/lib/fluxer/meilisearch 0750 root root -"];
      virtualisation.oci-containers.containers.fluxer-meilisearch = {
        image = "docker.io/getmeili/meilisearch:v1.12";
        environment = {
          MEILI_ENV = "production";
          MEILI_MAX_INDEXING_MEMORY = "384mb";
          MEILI_NO_ANALYTICS = "true";
        };
        environmentFiles = ["/run/fluxer-env/fluxer-meilisearch.env"];
        volumes = ["/var/lib/fluxer/meilisearch:/meili_data"];
        podman.sdnotify = "healthy";
        extraOptions = [
          "--memory=805306368"
          "--health-interval=10s"
          "--health-timeout=5s"
          "--health-retries=10"
          "--health-on-failure=kill"
          ("--health-cmd="
            + builtins.toJSON [
              "wget"
              "-q"
              "-O"
              "/dev/null"
              "http://127.0.0.1:7700/health"
            ])
        ];
      };
    };
  };
}

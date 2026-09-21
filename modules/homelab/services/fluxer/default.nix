{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
    # Service settings match upstream revision 34b6ecfbd27f29f2a7b9637ea7685e67e0582b85.
    components = [
      "admin"
      "api"
      "app-proxy"
      "edge"
      "gateway"
      "gifs"
      "gifs-shard"
      "livekit"
      "media-proxy"
      "meilisearch"
      "messages"
      "messages-shard"
      "nats"
      "seaweedfs"
      "snowflakes"
      "snowflakes-shard"
      "static-proxy"
      "unfurl"
      "unfurl-shard"
      "users"
      "users-shard"
      "valkey"
      "worker"
    ];
    containers = map (name: "fluxer-${name}") components;
    units = map (name: "podman-${name}") containers;
  in {
    options.services.homelab.fluxer = {
      enable = lib.mkEnableOption "Fluxer chat services with Caddy integration";
      imageTag = lib.mkOption {
        type = lib.types.str;
        default = "v1";
        description = "Tag for the Fluxer application images.";
      };
    };
    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = ["d /var/lib/fluxer 0750 root root -"];
      assertions = [
        {
          assertion = config.virtualisation.oci-containers.backend == "podman";
          message = "services.homelab.fluxer needs the Podman OCI backend.";
        }
      ];
      virtualisation.oci-containers.containers = lib.listToAttrs (map (name: {
          name = "fluxer-${name}";
          value = {
            autoStart = false;
            networks = ["fluxer_fluxer"];
            # Keep upstream DNS names after the container names change.
            extraOptions = ["--network-alias=${name}"];
          };
        })
        components);
      systemd.services =
        lib.genAttrs units (_: {
          requires = ["fluxer-network.service" "fluxer-storage.service"];
          after = ["fluxer-network.service" "fluxer-storage.service"];
          partOf = ["fluxer.target"];
          serviceConfig.RestartSec = 5;
        })
        // {
          fluxer-network = {
            description = "Podman network for Fluxer";
            path = [config.virtualisation.podman.package];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = "podman network exists fluxer_fluxer || podman network create fluxer_fluxer";
          };
        };
      systemd.targets.fluxer = {
        description = "Fluxer chat services";
        wantedBy = ["multi-user.target"];
        wants = (map (name: "${name}.service") units) ++ ["fluxer-seaweedfs-init.service"];
      };
    };
  };
}

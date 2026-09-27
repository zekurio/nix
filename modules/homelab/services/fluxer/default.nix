{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
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
        {
          assertion = lib.all (name:
            lib.all (volume: lib.hasPrefix "/" volume)
            config.virtualisation.oci-containers.containers.${name}.volumes)
          containers;
          message = "Fluxer storage must use absolute host paths, never named Podman volumes.";
        }
      ];
      virtualisation.oci-containers.containers = lib.listToAttrs (map (name: {
          name = "fluxer-${name}";
          value = {
            autoStart = false;
            networks = ["fluxer_fluxer"];
            # Keep upstream DNS names after the container names change.
            extraOptions = [
              "--network-alias=${name}"
              # Ignore Dockerfile VOLUME declarations; persistence is explicitly bind-mounted.
              "--image-volume=ignore"
            ];
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
            path = [config.virtualisation.podman.package pkgs.jq];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              if ! podman network exists fluxer_fluxer; then
                podman network create --subnet 10.89.42.0/24 --gateway 10.89.42.1 --interface-name fluxer0 fluxer_fluxer
              fi
              # The database address, HBA rule, and firewall depend on this network layout.
              if ! podman network inspect fluxer_fluxer | jq -e '
                .[0] | .network_interface == "fluxer0" and
                (.subnets == [{"subnet": "10.89.42.0/24", "gateway": "10.89.42.1"}])
              ' >/dev/null; then
                echo "Fluxer network has an obsolete layout. Stop and remove its containers, then remove fluxer_fluxer so it can be recreated." >&2
                exit 1
              fi
            '';
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

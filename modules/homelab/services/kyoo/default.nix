{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
    components = ["api" "auth" "edge" "front" "scanner" "transcoder"];
    containers = map (name: "kyoo-${name}") components;
    units = map (name: "podman-${name}") containers;
  in {
    options.services.homelab.kyoo = {
      enable = lib.mkEnableOption "Kyoo media server with Caddy integration";
      domain = lib.mkOption {
        type = lib.types.str;
        default = "media.${config.services.homelab.domains.zekurio}";
        description = "Public domain Kyoo is served on.";
      };
      imageTag = lib.mkOption {
        type = lib.types.str;
        # The default pull policy reuses the cached image, so bump this tag
        # to update rather than re-pulling a moving one.
        default = "5.2.1";
        description = "Tag for the Kyoo application images.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8901;
        description = "Loopback port of Kyoo's internal router.";
      };
      libraries = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          anime = "/tank/media/anime";
          movies = "/tank/media/movies";
          shows = "/tank/media/shows";
        };
        description = "Library directories, mounted read-only at /video/<name>.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.virtualisation.oci-containers.backend == "podman";
          message = "services.homelab.kyoo needs the Podman OCI backend.";
        }
      ];

      virtualisation.oci-containers.containers = lib.listToAttrs (map (name: {
          name = "kyoo-${name}";
          value = {
            autoStart = false;
            networks = ["kyoo"];
            # Keep upstream's compose service names; the images default to them.
            extraOptions = ["--network-alias=${name}"];
          };
        })
        components);

      systemd.services =
        lib.genAttrs units (_: {
          requires = ["kyoo-network.service"];
          after = ["kyoo-network.service"];
          partOf = ["kyoo.target"];
          serviceConfig.RestartSec = 5;
        })
        // {
          kyoo-network = {
            description = "Podman network for Kyoo";
            path = [config.virtualisation.podman.package];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              podman network exists kyoo || podman network create kyoo
            '';
          };
        };

      systemd.targets.kyoo = {
        description = "Kyoo media server";
        wantedBy = ["multi-user.target"];
        wants = map (name: "${name}.service") units;
      };
    };
  };
}

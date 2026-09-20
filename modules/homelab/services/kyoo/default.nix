{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
    version = "5.2.1";
    components = ["api" "auth" "front" "scanner" "transcoder"];
    containers = map (name: "kyoo-${name}") (components ++ ["postgres" "proxy"]);
    units = map (name: "podman-${name}") containers;
    publicUrl = "https://stream.${config.services.homelab.domains.zekurio}";
  in {
    options.services.homelab.kyoo.enable = lib.mkEnableOption "Kyoo media services with Caddy integration";

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.virtualisation.oci-containers.backend == "podman";
          message = "services.homelab.kyoo needs the Podman OCI backend.";
        }
      ];

      virtualisation.oci-containers.containers = lib.mkMerge [
        (lib.genAttrs containers (_: {
          networks = ["kyoo"];
          autoStart = false;
        }))
        (lib.listToAttrs (map (name: {
            name = "kyoo-${name}";
            value.image = "ghcr.io/zoriya/kyoo_${name}:${version}";
          })
          components))
        (lib.genAttrs ["kyoo-api" "kyoo-scanner" "kyoo-transcoder"] (_: {
          environment = {
            JWT_ISSUER = publicUrl;
            JWKS_URL = "http://kyoo-auth:4568/.well-known/jwks.json";
          };
        }))
        {kyoo-auth.environment.PUBLIC_URL = publicUrl;}
      ];

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
            # Keep the network across stops. Each container owns its lifecycle.
            script = ''
              podman network exists kyoo || podman network create --subnet 10.89.1.0/24 --gateway 10.89.1.1 kyoo
            '';
          };
        };
      systemd.targets.kyoo = {
        description = "Kyoo media services";
        wantedBy = ["multi-user.target"];
        wants = map (name: "${name}.service") units;
      };
    };
  };
}

{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
  in {
    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.kyoo-front = {
        image = "ghcr.io/zoriya/kyoo_front:${cfg.imageTag}";
        # Server-side rendering talks to the API directly. Upstream's compose
        # default (api:5000) is not a port the API listens on.
        environment.KYOO_URL = "http://api:3567/api";
      };
    };
  };
}

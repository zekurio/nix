{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
  in {
    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = ["d /var/lib/kyoo/images 0750 root root -"];

      virtualisation.oci-containers.containers.kyoo-api = {
        image = "ghcr.io/zoriya/kyoo_api:${cfg.imageTag}";
        environment = {
          JWT_ISSUER = "https://${cfg.domain}";
          IMAGES_PATH = "/images";
        };
        volumes = ["/var/lib/kyoo/images:/images"];
        dependsOn = ["kyoo-auth"];
      };
    };
  };
}

{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: {
    config = lib.mkIf config.services.homelab.kyoo.enable {
      systemd.tmpfiles.rules = ["d /var/lib/kyoo/images 0750 root root -"];
      virtualisation.oci-containers.containers.kyoo-api = {
        environment = {
          IMAGES_PATH = "/images";
          AUTH_SERVER = "http://kyoo-auth:4568";
          TRANSCODER_SERVER = "http://kyoo-transcoder:7666";
        };
        volumes = ["/var/lib/kyoo/images:/images"];
      };
    };
  };
}

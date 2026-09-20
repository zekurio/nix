{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: {
    config = lib.mkIf config.services.homelab.kyoo.enable {
      systemd.tmpfiles.rules = ["d /var/lib/kyoo/metadata 0750 root root -"];
      virtualisation.oci-containers.containers.kyoo-transcoder = {
        dependsOn = ["kyoo-auth"];
        devices = ["/dev/dri:/dev/dri"];
        environment = {
          GOCODER_HWACCEL = "vaapi";
          GOCODER_VAAPI_RENDERER = "/dev/dri/renderD128";
        };
        volumes = [
          "/tank/media:/video:ro"
          "/var/cache/kyoo:/cache"
          "/var/lib/kyoo/metadata:/metadata"
        ];
      };
      systemd.services.podman-kyoo-transcoder = {
        unitConfig.RequiresMountsFor = ["/tank/media"];
        serviceConfig.CacheDirectory = "kyoo";
      };
    };
  };
}

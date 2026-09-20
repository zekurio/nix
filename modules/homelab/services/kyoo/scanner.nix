{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: {
    config = lib.mkIf config.services.homelab.kyoo.enable {
      sops.templates."kyoo-scanner.env" = {
        content = ''
          KYOO_APIKEY=${config.sops.placeholder.kyoo_api_key}
        '';
        restartUnits = ["podman-kyoo-scanner.service"];
      };
      virtualisation.oci-containers.containers.kyoo-scanner = {
        dependsOn = ["kyoo-proxy"];
        environmentFiles = [config.sops.templates."kyoo-scanner.env".path];
        environment = {
          KYOO_URL = "http://kyoo-proxy:8901/api";
          LIBRARY_IGNORE_PATTERN = ".*/(music|[dD]ownloads?)/.*";
        };
        volumes = ["/tank/media:/video:ro"];
      };
      systemd.services.podman-kyoo-scanner.unitConfig.RequiresMountsFor = ["/tank/media"];
    };
  };
}

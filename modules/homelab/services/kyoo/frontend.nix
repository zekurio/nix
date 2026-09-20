{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: {
    config = lib.mkIf config.services.homelab.kyoo.enable {
      # Server-side requests need the proxy's token exchange before the API.
      virtualisation.oci-containers.containers.kyoo-front.environment.KYOO_URL = "http://kyoo-proxy:8901/api";
    };
  };
}

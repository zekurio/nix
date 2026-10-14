{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
    clients = ["kyoo-auth" "kyoo-scanner"];
  in {
    config = lib.mkIf cfg.enable {
      # Podman reads env files literally, so values must not be quoted:
      #   OIDC_POCKETID_CLIENTID=...
      #   OIDC_POCKETID_SECRET=...
      #   KEIBI_APIKEY_SCANNER=...
      #   KYOO_APIKEY=...  (same value; the scanner presents the key auth registers)
      sops.secrets.kyoo_env.restartUnits = map (name: "podman-${name}.service") clients;

      virtualisation.oci-containers.containers = lib.genAttrs clients (_: {
        environmentFiles = [config.sops.secrets.kyoo_env.path];
      });
    };
  };
}

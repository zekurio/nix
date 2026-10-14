{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
  in {
    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = [
        "d /var/lib/kyoo/transcoder 0750 root root -"
        # Transcoded segments; the transcoder clears this itself.
        "d /var/cache/kyoo 0750 root root -"
      ];

      virtualisation.oci-containers.containers.kyoo-transcoder = {
        image = "ghcr.io/zoriya/kyoo_transcoder:${cfg.imageTag}";
        environment = {
          GOCODER_HWACCEL = "vaapi";
          GOCODER_VAAPI_RENDERER = "/dev/dri/renderD128";
          JWKS_URL = "http://auth:4568/.well-known/jwks.json";
        };
        # Must expose the same /video paths as the scanner.
        volumes =
          lib.mapAttrsToList (name: path: "${path}:/video/${name}:ro") cfg.libraries
          ++ [
            "/var/cache/kyoo:/cache"
            "/var/lib/kyoo/transcoder:/metadata"
          ];
        devices = ["/dev/dri:/dev/dri"];
        dependsOn = ["kyoo-auth"];
      };
    };
  };
}

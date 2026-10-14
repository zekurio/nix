{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.kyoo;
  in {
    config = lib.mkIf cfg.enable {
      # Kyoo identifies media from the path alone (title, year, SxxEyy) and
      # never reads provider IDs from it. Numbers in Jellyfin-style
      # `[tmdbid-128]` suffixes are parsed as episode numbers, so library
      # folders must follow the plain TRaSH naming configarr applies.
      virtualisation.oci-containers.containers.kyoo-scanner = {
        image = "ghcr.io/zoriya/kyoo_scanner:${cfg.imageTag}";
        environment = {
          # Through the router, which swaps the API key for a JWT.
          KYOO_URL = "http://edge:8901/api";
          JWT_ISSUER = "https://${cfg.domain}";
          # Matched against the full path. media-cleanup remuxes next to the
          # original under this prefix before swapping the file in.
          LIBRARY_IGNORE_PATTERN = ''.*/\.media-cleanup-[^/]*$'';
        };
        volumes = lib.mapAttrsToList (name: path: "${path}:/video/${name}:ro") cfg.libraries;
        dependsOn = ["kyoo-api"];
      };
    };
  };
}

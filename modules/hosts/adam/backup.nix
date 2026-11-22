{
  config,
  lib,
  ...
}: let
  homelab = config.services.homelab;
in {
  services.homelab.backup = {
    enable = true;
    startAt = "Sun *-*-* 03:00:00";

    exclude = [
      # The download tree shares the SSD with the system. Everything in it
      # can be downloaded again, and it churns daily.
      homelab.mediaShare.downloadsRoot
      "/home"
      # Matinee replaced these services. Seerr used two StateDirectory names,
      # with symlinks under /var/lib and the data under /var/lib/private.
      "/var/lib/jellyfin"
      "/var/lib/inviterr"
      "/var/lib/seerr"
      "/var/lib/jellyseerr"
      "/var/lib/private/seerr"
      "/var/lib/private/jellyseerr"
      # Immich regenerates these from the originals.
      "/tank/immich/thumbs"
      "/tank/immich/encoded-video"
    ];

    offsite = {
      host = "u699442-sub1.your-storagebox.de";
      # SHA256:XqONwb1S0zuj5A1CDxpOSuD2hnAArV1A3wKY7Z3sdgM // every Storage Box
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
      datasets =
        [
          "tank/immich"
          "tank/alloy"
          "tank/shares"
        ]
        ++ map (share: share.dataset) (lib.attrValues homelab.mediaShare.userShares)
        ++ lib.optional homelab.fluxer.enable "tank/fluxer";
    };
  };
}

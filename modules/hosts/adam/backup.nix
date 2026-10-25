{
  config,
  lib,
  ...
}: let
  homelab = config.services.homelab;
in {
  services.homelab.backup = {
    enable = true;

    # Build output and package caches in the home directories, which
    # rebuild or download again. They change daily, so every daily snapshot
    # of the copy would keep them.
    exclude = [
      "/home/*/Git/**/target/"
      "/home/*/Git/**/node_modules/"
      "/home/*/.cargo/registry/"
      "/home/*/go/pkg/mod/"
      "/home/*/.npm/"
      "/home/*/.local/share/pnpm/"
      "/home/*/.local/share/NuGet/"
      # Rootless Podman keeps no volumes here, only images.
      "/home/*/.local/share/containers/storage/"
      "/home/*/.local/share/zed/external_agents/"
      "/home/*/.local/share/zed/languages/"
      "/home/*/.local/share/zed/node/"
      "/home/*/.zed_server/"
    ];

    # What a total loss of adam must not take: photos and clips, Fluxer's
    # messages and attachments, and everyone's shares.
    offsite = {
      enable = true;
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
      paths = [
        # Every database, Fluxer's messages included.
        homelab.backup.dumpDir
        # Alloy keeps thumbnails and avatars on the SSD.
        "/var/lib/alloy"
        # Immich and Fluxer log in through Pocket ID; its passkeys and
        # OIDC clients keep those accounts reachable.
        config.services.pocket-id.dataDir
        # A reinstall that restores this first hands out the same UIDs, so
        # the restored files keep their owners.
        "/var/lib/nixos"
      ];
      # Immich regenerates both from the originals.
      exclude = [
        "/tank/immich/thumbs"
        "/tank/immich/encoded-video"
      ];
    };
  };
}

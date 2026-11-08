{
  lib,
  pkgs,
  ...
}: let
  share = "/home/zekurio/Meine Dateien";

  # NetworkManager takes eno1 down as soon as logind announces suspend, and
  # the kernel syncs every filesystem only after that. Dirty pages on this
  # hard mount then wait forever for a server they cannot reach, with the
  # session already frozen: the screen hangs at "PM: suspend entry" and the
  # journal never gets "Filesystems sync". pre-down runs while the link is
  # still up and NetworkManager waits for it, so flush the share there and
  # drop the mount if nothing holds it. The automount mounts it again on the
  # next access after resume.
  flushShare = pkgs.writeShellApplication {
    name = "personal-share-flush";
    runtimeInputs = [pkgs.coreutils pkgs.util-linux];
    text = ''
      share=${lib.escapeShellArg share}
      [[ "''${2:-}" == pre-down ]] || exit 0
      mountpoint -q "$share" || exit 0
      # logind starts the suspend anyway once its 5 s inhibitor delay runs
      # out, so a slow flush cannot hold the suspend back.
      sync -f "$share" || echo "flushing $share failed"
      umount "$share" 2> /dev/null || echo "$share is busy, kept mounted after flushing"
    '';
  };
in {
  # Automount on first access so an unavailable server cannot delay boot.
  fileSystems.${share} = {
    # adam exports /tank as the NFSv4 root, so the path is relative to it;
    # the export is in modules/hosts/adam/personal-share.nix.
    device = "10.0.0.2:/shares/zekurio";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "rw"
      "_netdev"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=10min"
      "x-systemd.mount-timeout=10s"
    ];
  };

  # Runs for every interface NetworkManager takes down cleanly, not only for
  # the one carrying NFS, since a VPN can change which route that is.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "pre-down";
      source = lib.getExe flushShare;
    }
  ];
}

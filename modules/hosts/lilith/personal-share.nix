{
  # Automount on first access so an unavailable server cannot delay boot.
  fileSystems."/home/zekurio/Meine Dateien" = {
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
}

{...}: {
  fileSystems."/var/lib/downloads" = {
    device = "/dev/disk/by-label/downloads";
    fsType = "ext4";
    options = ["noatime"];
  };
}

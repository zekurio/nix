{
  flake.modules.nixos.adam = {config, ...}: {
    fileSystems.${config.modules.homelab.mediaShare.downloadsRoot} = {
      device = "/dev/disk/by-label/downloads";
      fsType = "ext4";
      options = ["noatime"];
    };
  };
}

{
  flake.modules.nixos.adam = {config, ...}: {
    fileSystems.${config.services.homelab.mediaShare.downloadsRoot} = {
      device = "/dev/disk/by-label/downloads";
      fsType = "ext4";
      options = ["noatime"];
    };
  };
}

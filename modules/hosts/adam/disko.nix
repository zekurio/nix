{inputs, ...}: {
  imports = [inputs.disko.nixosModules.disko];

  disko.devices = {
    disk = {
      # Disko labels the partitions disk-<name>-<partition> and mounts them by
      # those labels. "main" labelled the old 850 EVO, so a new name lets
      # both disks sit in adam during the move without a label clash.
      system = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-CT1000P3PSSD8_2322E6DD1319_1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["fmask=0077" "dmask=0077"];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}

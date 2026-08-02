{inputs, ...}: {
  flake.modules.nixos.lilith = {
    imports = [inputs.disko.nixosModules.disko];

    # Windows lives on its own drive. This deliberately owns and wipes only
    # Lilith's known Crucial NVMe; re-check the by-id path before installing.
    disko.devices.disk.system = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-CT1000P3PSSD8_2322E6DD1319_1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
          };

          swap = {
            size = "16G";
            content = {
              type = "swap";
              discardPolicy = "both";
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
}

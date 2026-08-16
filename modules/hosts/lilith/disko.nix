{inputs, ...}: {
  flake.modules.nixos.lilith = {
    imports = [inputs.disko.nixosModules.disko];

    # NixOS owns the Samsung NVMe. The Crucial NVMe stays empty for Windows.
    # The serial-based paths prevent disk order changes from selecting a USB disk.
    disko.devices.disk = {
      system = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNX0T205473J_1";
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

      windows = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-CT1000P3PSSD8_2322E6DD1319_1";
        content = {
          type = "gpt";
          partitions = {};
        };
      };
    };
  };
}

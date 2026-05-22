{
  disko.devices = {
    disk = {
      nixos = {
        type = "disk";
        # Replace with Sachiel's stable NVMe disk id before running disko.
        device = "/dev/disk/by-id/nvme-TODO-sachiel-root-disk";
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
                mountOptions = ["fmask=0077" "dmask=0077"];
              };
            };

            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "lvm_pv";
                  vg = "sachiel";
                };
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      sachiel = {
        type = "lvm_vg";
        lvs = {
          swap = {
            # 16 GiB RAM; leave headroom for hibernation image overhead.
            size = "20G";
            content = {
              type = "swap";
              discardPolicy = "both";
              resumeDevice = true;
            };
          };

          root = {
            size = "100%FREE";
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

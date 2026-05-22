{
  disko.devices = {
    disk = {
      nixos = {
        type = "disk";
        # nvme0n1 — Linux/NixOS disk (Windows lives on nvme1n1, untouched)
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_1TB_S7M9NL0X315196K";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "4G";
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

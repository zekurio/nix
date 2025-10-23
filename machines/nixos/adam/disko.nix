{ ... }:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Change this to match your actual disk device (e.g., /dev/nvme0n1, /dev/sda)
        device = "/dev/sda";
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
                # Restrict permissions: owner read/write/execute, group and others read/execute only
                mountOptions = [ "fmask=0077" "dmask=0077" ];
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

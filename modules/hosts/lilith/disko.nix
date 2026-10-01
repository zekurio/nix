{inputs, ...}: {
  flake.modules.nixos.lilith = {
    imports = [inputs.disko.nixosModules.disko];

    # NixOS owns the Samsung NVMe. Disko must not know about the Crucial Windows
    # drive, since destroy mode wipes every disk declared here.
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

            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-L"
                  "nixos"
                ];
                subvolumes = let
                  mountOptions = [
                    "compress=zstd:1"
                    "discard=async"
                    "noatime"
                  ];
                in {
                  "@" = {
                    mountpoint = "/";
                    inherit mountOptions;
                  };
                  "@home" = {
                    mountpoint = "/home";
                    inherit mountOptions;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    inherit mountOptions;
                  };
                  # Keep swap outside snapshotted subvolumes. Disko disables
                  # copy-on-write for the file before allocating it.
                  "@swap" = {
                    mountpoint = "/swap";
                    mountOptions = ["noatime"];
                    swap.swapfile.size = "16G";
                  };
                };
              };
            };
          };
        };
      };
    };

    services.btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = ["/"];
    };
  };
}

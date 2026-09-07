{
  flake.modules.nixos.adam = {pkgs, ...}: {
    environment.systemPackages = [pkgs.smartmontools];

    services.smartd = {
      enable = true;
      # Also monitor the system/download SSDs and newly connected drives.
      autodetect = true;
      defaults.monitored = "-a -W 4,50,60";
      devices = [
        {
          device = "/dev/disk/by-id/ata-WDC_WD80EFPX-68C4ZN0_WD-RD3KAA5G";
          options = "-s (S/../../6/03|L/../10/./01)";
        }
        {
          device = "/dev/disk/by-id/ata-ST8000VN004-3CP101_WWZBKNQN";
          options = "-s (S/../../7/03|L/../17/./01)";
        }
      ];
    };

    # Keep the scrub separate from both disks' monthly extended tests.
    services.zfs.autoScrub = {
      enable = true;
      pools = ["tank"];
      interval = "*-*-24 01:00:00";
    };
  };
}

{pkgs, ...}: {
  environment.systemPackages = [pkgs.smartmontools];

  services.smartd = {
    enable = true;
    # Also monitor the system/download SSDs and newly connected drives.
    autodetect = true;
    # `-a` without its `-t`, which logged every normalized attribute change
    # (temperatures, the IronWolf's drifting Raw_Read_Error_Rate) every 30
    # minutes; none of that is ever notified. `-M daily` repeats an alert
    # until the problem is gone instead of sending it once per boot.
    defaults.monitored = "-H -f -l error -l selftest -C 197 -U 198 -W 0,45,55 -M daily";
    # The flash drives run hotter than the HDDs; NVMe skips the ATA-only checks.
    defaults.autodetected = "-H -f -l error -l selftest -C 197 -U 198 -W 0,60,70 -M daily";
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
}

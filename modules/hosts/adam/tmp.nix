{...}: {
  flake.modules.nixos.adam = {...}: {
    # /tmp and /var/tmp otherwise both live on the root ext4, so disk
    # dashboards list them twice with identical stats. A RAM-backed /tmp is
    # its own filesystem with distinct stats and gets wiped on reboot for
    # free. /var/tmp stays on disk (persistent per FHS); systemd's stock
    # tmpfiles rules already age out entries older than 30 days.
    boot.tmp.useTmpfs = true;
  };
}

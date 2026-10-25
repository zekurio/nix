{
  # Compressed swap in RAM, as CachyOS ships it. The 16 GiB swapfile from
  # disko stays at its default negative priority as an overflow; there is no
  # hibernation on this host.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  # The CachyOS kernel enables zswap by default. Stacked in front of zram
  # it would compress pages twice, so it has to go.
  boot.kernelParams = ["zswap.enabled=0"];

  # Reclaim into zram early: it is far cheaper than disk and the page cache
  # is worth more than anonymous pages that went cold.
  boot.kernel.sysctl."vm.swappiness" = 150;
}

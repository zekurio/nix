{
  # A compressed tier in RAM in front of the swapfile, which stays as the
  # overflow on the SATA SSD, so swapped pages usually come back without a
  # disk read. adam's kernel leaves zswap off, so nothing compresses them
  # twice.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
    priority = 100;
  };
}

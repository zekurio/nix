{
  # adam rebuilds several times a day, so the shared weekly sweep of
  # week-old generations left ~60 GB of dead store paths on the SSD.
  nix.gc = {
    dates = "daily";
    options = "--delete-older-than 3d";
  };

  # A build that drops below min-free collects garbage until max-free is
  # available, instead of filling the SSD between the daily runs.
  nix.settings = {
    min-free = 10 * 1024 * 1024 * 1024;
    max-free = 40 * 1024 * 1024 * 1024;
  };
}

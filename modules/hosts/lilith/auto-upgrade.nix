{
  # Builds main in the background and only makes it the boot default, so a
  # running session never changes underneath. The next reboot boots main,
  # discarding any unpushed generation switched to from the local checkout.
  system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix/main#lilith";
    operation = "boot";
    dates = "daily";
    randomizedDelaySec = "30min";
    allowReboot = false;
  };

  # The flake is evaluated in this unit, not by the daemon that nix-daemon.nix
  # already idles, and evaluation alone takes a core for half a minute.
  systemd.services.nixos-upgrade.serviceConfig = {
    CPUSchedulingPolicy = "idle";
    IOSchedulingClass = "idle";
    Nice = 19;
  };
}

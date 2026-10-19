{
  # Builds main in the background and only makes it the boot default, so a
  # running session never changes underneath. The next reboot boots main,
  # discarding any unpushed generation switched to from the local checkout.
  flake.modules.nixos.lilith.system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix/main#lilith";
    operation = "boot";
    dates = "daily";
    randomizedDelaySec = "30min";
    allowReboot = false;
  };
}

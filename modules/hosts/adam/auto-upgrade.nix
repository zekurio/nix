{
  flake.modules.nixos.adam.system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix/main#adam";
    dates = "Sun *-*-* 03:00:00";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };
}

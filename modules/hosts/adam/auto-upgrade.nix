{
  system.autoUpgrade = {
    enable = true;
    flake = "github:zekurio/nix/main#adam";
    dates = "Sun *-*-* 03:00:00";
    persistent = false;
    allowReboot = false;
  };
}

{
  flake.modules.nixos.adam = {pkgs, ...}: {
    environment.systemPackages = [pkgs.lsof];
  };
}

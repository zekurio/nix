{inputs, ...}: {
  imports = [
    inputs.catppuccin.nixosModules.catppuccin
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./configuration.nix
    ./desktop
    ./hardware-support.nix
  ];
}

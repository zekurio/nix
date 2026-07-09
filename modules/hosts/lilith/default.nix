{inputs, ...}: {
  imports = [
    inputs.catppuccin.nixosModules.catppuccin
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./configuration.nix
    ./fonts.nix
    ./gaming.nix
    ./hardware-support.nix
    ./helium.nix
    ./plasma.nix
    ./desktop-apps.nix
  ];
}

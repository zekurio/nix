{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./configuration.nix
    ./fonts.nix
    ./hardware-support.nix
    ./helium.nix
    ./plasma.nix
    ./desktop-apps.nix
  ];
}

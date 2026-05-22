{inputs, ...}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./configuration.nix
  ];
}

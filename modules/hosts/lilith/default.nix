{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.dms.nixosModules.default
    inputs.dms.nixosModules.greeter
    inputs.home-manager.nixosModules.home-manager
    ./configuration.nix
  ];
}

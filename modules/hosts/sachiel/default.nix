{inputs, ...}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./configuration.nix
  ];
}

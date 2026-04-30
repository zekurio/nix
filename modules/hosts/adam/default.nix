{inputs, ...}: {
  imports = [
    inputs.alloy.nixosModules.default
    inputs.autoaspm.nixosModules.default
    ../../homelab
    ./configuration.nix
  ];
}

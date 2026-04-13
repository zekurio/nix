{inputs, ...}: {
  imports = [
    inputs.autoaspm.nixosModules.default
    ../../homelab
    ./configuration.nix
  ];
}

{inputs, ...}: {
  imports = [
    ../_common/workstation
    inputs.nixos-hardware.nixosModules.asus-battery
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga401
    ./configuration.nix
  ];
}

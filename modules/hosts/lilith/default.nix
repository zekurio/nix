{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.dms.nixosModules.dank-material-shell
    inputs.dms.nixosModules.greeter
    ../_common/desktop
    ./configuration.nix
  ];
}

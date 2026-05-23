{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.autoaspm.nixosModules.default
    ../_common/desktop
    ./disko.nix
    ./configuration.nix
  ];
}

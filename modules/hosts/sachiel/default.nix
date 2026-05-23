{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    ../_common/desktop
    ./disko.nix
    ./configuration.nix
  ];
}

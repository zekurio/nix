{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.autoaspm.nixosModules.default
    ../_common/desktop
    ../_common/desktop/kde.nix
    ./disko.nix
    ./configuration.nix
  ];
}

{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.autoaspm.nixosModules.default
    ./disko.nix
    ./configuration.nix
  ];
}

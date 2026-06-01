{inputs, ...}: {
  imports = [
    inputs.autoaspm.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    inputs.ucodenix.nixosModules.default
    ../../homelab
    ./configuration.nix
  ];
}

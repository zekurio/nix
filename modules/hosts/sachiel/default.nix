{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    (inputs.nixos-hardware + "/asus/zephyrus/ga401")
    ./configuration.nix
  ];
}

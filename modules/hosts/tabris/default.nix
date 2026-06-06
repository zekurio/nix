{inputs, ...}: {
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ./configuration.nix
  ];
}

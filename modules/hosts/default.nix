{inputs, ...}: let
  inherit (inputs.nixpkgs-unstable) lib;

  commonModules = [
    ./_common
    inputs.home-manager.nixosModules.home-manager
  ];

  nixosModules = [
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    inputs.ucodenix.nixosModules.default
  ];

  mkHost = extraModules: hostModule:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules = commonModules ++ extraModules ++ [hostModule];
    };
in {
  flake.nixosConfigurations = {
    adam = mkHost nixosModules ./adam;
  };
}

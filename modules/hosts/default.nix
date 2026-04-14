{inputs, ...}: let
  inherit (inputs.nixpkgs-unstable) lib;

  commonModules = [
    ./_common
    inputs.home-manager.nixosModules.home-manager
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
  ];

  mkHost = hostModule:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules = commonModules ++ [hostModule];
    };
in {
  flake.nixosConfigurations = {
    adam = mkHost ./adam;
    lilith = mkHost ./lilith;
    sachiel = mkHost ./sachiel;
  };
}

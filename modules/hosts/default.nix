{inputs, ...}: let
  inherit (inputs.nixpkgs-unstable) lib;

  commonModules = [
    ./_common
    inputs.home-manager.nixosModules.home-manager
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
    tabris = mkHost ./tabris;
  };
}

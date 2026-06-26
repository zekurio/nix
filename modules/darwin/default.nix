{inputs, ...}: let
  inherit (inputs.nixpkgs-unstable) lib;

  commonModules = [
    ./_common
    inputs.home-manager.darwinModules.home-manager
  ];

  mkDarwin = hostModule:
    inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {inherit inputs;};
      modules = commonModules ++ [hostModule];
    };
in {
  flake.darwinConfigurations = {
    darwin = mkDarwin ./darwin;
  };
}

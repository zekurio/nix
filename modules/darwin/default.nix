{inputs, ...}: let
  commonModules = [
    ./_common
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  mkDarwin = hostModule:
    inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = {inherit inputs;};
      modules = commonModules ++ [hostModule];
    };
in {
  flake.darwinConfigurations.sachiel = mkDarwin ./sachiel;
}

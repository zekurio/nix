{
  config,
  inputs,
  ...
}: {
  flake.darwinConfigurations.sachiel = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    specialArgs = {inherit inputs;};
    modules = with config.flake.modules.darwin; [
      base
      inputs.home-manager.darwinModules.home-manager
      inputs.nix-homebrew.darwinModules.nix-homebrew
      sachiel
    ];
  };
}

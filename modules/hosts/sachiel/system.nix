{
  config,
  inputs,
  ...
}: {
  flake.darwinConfigurations.sachiel = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = {inherit inputs;};
    modules = with config.flake.modules.darwin; [
      base
      sachiel
    ];
  };
}

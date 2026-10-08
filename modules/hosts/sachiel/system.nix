{
  config,
  inputs,
  ...
}: {
  flake.darwinConfigurations.sachiel = inputs.nix-darwin.lib.darwinSystem {
    modules = with config.flake.modules.darwin; [
      base
      sachiel
    ];
  };
}

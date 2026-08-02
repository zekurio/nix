{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.lilith = inputs.nixpkgs-unstable.lib.nixosSystem {
    specialArgs = {inherit inputs;};
    modules = with config.flake.modules.nixos; [
      base
      lilith
      gaming
    ];
  };
}

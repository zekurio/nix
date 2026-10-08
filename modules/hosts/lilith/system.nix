{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.lilith = inputs.nixpkgs-unstable.lib.nixosSystem {
    modules = with config.flake.modules.nixos; [
      base
      lilith
    ];
  };
}

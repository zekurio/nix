{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.ramiel = inputs.nixpkgs-stable.lib.nixosSystem {
    specialArgs = {inherit inputs;};
    modules = with config.flake.modules.nixos; [
      base
      ramiel
    ];
  };
}

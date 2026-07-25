{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.adam = inputs.nixpkgs-unstable.lib.nixosSystem {
    specialArgs = {inherit inputs;};
    modules = with config.flake.modules.nixos; [
      base
      adam
      homelab
    ];
  };
}

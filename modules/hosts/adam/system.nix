{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.adam = inputs.nixpkgs-unstable.lib.nixosSystem {
    modules = with config.flake.modules.nixos; [
      base
      adam
      homelab
    ];
  };
}

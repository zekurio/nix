{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.sachiel = inputs.nixpkgs-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs self;
    };
    modules = [
      ../_common
      ../../desktop
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      ./configuration.nix
    ];
  };
}

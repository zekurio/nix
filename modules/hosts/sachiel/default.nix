{inputs, ...}: {
  flake.nixosConfigurations.sachiel = inputs.nixpkgs-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules = [
      ../_common
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      inputs.sops-nix.nixosModules.sops
      ../../desktop
      ../../gaming
      ./configuration.nix
    ];
  };
}

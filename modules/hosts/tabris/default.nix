{inputs, ...}: {
  flake.nixosConfigurations.tabris = inputs.nixpkgs-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
    };
    modules = [
      ../_common
      inputs.home-manager.nixosModules.home-manager
      inputs.nixos-wsl.nixosModules.default
      ./configuration.nix
    ];
  };
}

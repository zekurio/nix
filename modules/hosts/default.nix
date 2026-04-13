{inputs, ...}: let
  mkHost = extraModules:
    inputs.nixpkgs-unstable.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules =
        [
          ./_common
          inputs.home-manager.nixosModules.home-manager
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
        ]
        ++ extraModules;
    };
in {
  flake.nixosConfigurations = {
    adam = mkHost [
      inputs.autoaspm.nixosModules.default
      ../homelab
      ./adam/configuration.nix
    ];

    lilith = mkHost [
      ../desktop
      ../gaming
      ./lilith/configuration.nix
    ];

    sachiel = mkHost [
      ../desktop
      ../gaming
      ./sachiel/configuration.nix
    ];
  };
}

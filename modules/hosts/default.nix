{
  config,
  inputs,
  ...
}: {
  flake.nixosConfigurations.adam = inputs.nixpkgs-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules = [
      inputs.home-manager.nixosModules.home-manager
      config.flake.modules.nixos.base
      {
        imports = [
          # Import depth is load-bearing: it reproduces the module system's
          # DFS merge order from the pre-dendritic layout, keeping list-typed
          # options (PATH entries, etc.) byte-identical. Do not flatten.
          {imports = [{imports = [inputs.autoaspm.nixosModules.default];}];}
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          inputs.ucodenix.nixosModules.default
          config.flake.modules.nixos.adam
          config.flake.modules.nixos.homelab
        ];
      }
    ];
  };
}

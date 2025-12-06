{
  description = "NixOS configurations for homelab and workstations";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://cachix.cachix.org"
      "https://nixpkgs.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    download-buffer-size = 1073741824;
  };

  # Flake inputs: external dependencies and frameworks
  inputs = {
    # Core dependencies
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11?shallow=true";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable?shallow=true";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # NixOS deployment and infrastructure
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System configuration management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware and security
    autoaspm = {
      url = "github:notthebee/AutoASPM";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement = {
      url = "github:Maroka-chan/VPN-Confinement";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      ...
    }:
    let
      lib = nixpkgs.lib;

      # Shared modules applied to all hosts
      sharedModules = [
        ./modules/system
        ./modules/users
        ./modules/profiles/dev.nix
        ./machines/nixos
        inputs.home-manager.nixosModules.home-manager
        (import ./overlays inputs)
      ];

      mkSpecialArgs = {
        inherit inputs;
      };

      # Host definitions with their specific modules and system architecture
      hosts = {
        adam = {
          system = "x86_64-linux";
          modules = [
            inputs.disko.nixosModules.disko
            inputs.autoaspm.nixosModules.default
            inputs.sops-nix.nixosModules.sops
            inputs.vpn-confinement.nixosModules.default
            ./modules/homelab
            ./machines/nixos/adam/configuration.nix
          ];
        };
        tabris = {
          system = "x86_64-linux";
          pkgsInput = inputs.nixpkgs-unstable;
          modules = [
            inputs.nixos-wsl.nixosModules.default
            ./machines/nixos/tabris/configuration.nix
          ];
        };
      };

      # Build NixOS configurations from host definitions
      mkSystem = lib.mapAttrs (
        _: host:
        let
          pkgsInput = host.pkgsInput or nixpkgs;
        in
        pkgsInput.lib.nixosSystem {
          inherit (host) system;
          specialArgs = mkSpecialArgs;
          modules = sharedModules ++ host.modules;
        }
      );
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      _module.args = {
        inherit inputs lib;
      };

      flake = {
        overlays.default = import ./overlays inputs;
        nixosConfigurations = mkSystem hosts;
      };
    };
}

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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable?shallow=true";
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
    # System configuration management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement = {
      url = "github:Maroka-chan/VPN-Confinement";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }: let
    lib = nixpkgs.lib;

    # Shared modules applied to all hosts
    sharedModules = [
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
          inputs.sops-nix.nixosModules.sops
          inputs.vpn-confinement.nixosModules.default
          ./modules/homelab
          ./machines/nixos/adam/configuration.nix
        ];
      };
      tabris = {
        system = "x86_64-linux";
        modules = [
          inputs.nixos-wsl.nixosModules.default
          ./machines/nixos/tabris/configuration.nix
        ];
      };
      lilith = {
        system = "x86_64-linux";
        modules = [
          inputs.disko.nixosModules.disko
          inputs.lanzaboote.nixosModules.lanzaboote
          ./machines/nixos/lilith/configuration.nix
        ];
      };
    };

    # Build NixOS configurations from host definitions
    mkSystem = lib.mapAttrs (
      _: host:
        nixpkgs.lib.nixosSystem {
          inherit (host) system;
          specialArgs = mkSpecialArgs;
          modules = sharedModules ++ host.modules;
        }
    );
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      _module.args = {
        inherit inputs lib;
      };

      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;
      };

      flake = {
        overlays.default = import ./overlays inputs;
        nixosConfigurations = mkSystem hosts;

        packages.x86_64-linux = let
          overlay = import ./overlays/jellyseerr-develop.nix inputs;
          pkgs = nixpkgs.legacyPackages.x86_64-linux.extend overlay;
        in {
          jellyseerr = pkgs.jellyseerr;
        };
      };
    };
}

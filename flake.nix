{
  description = "NixOS configuration with flake-parts";

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
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
    };
    autoaspm = {
      url = "github:notthebee/AutoASPM";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement = {
      url = "github:Maroka-chan/VPN-Confinement";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    dms-cli = {
      url = "github:AvengeMedia/danklinux";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    dankMaterialShell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.dgop.follows = "dgop";
      inputs.dms-cli.follows = "dms-cli";
    };
  };

  outputs = inputs@{ nixpkgs, nixpkgs-unstable, flake-parts, disko, ... }:
    let
      lib = nixpkgs.lib;
      # Helper to create pre-configured unstable pkgs with allowUnfree
      mkPkgsUnstable = system: import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      pkgsUnstable = mkPkgsUnstable "x86_64-linux";
      # Shared Nix configuration for all machines
      commonNixConfig = {
        nix.settings = {
          experimental-features = [ "nix-command" "flakes" ];
          trusted-users = [ "root" "@wheel" ];
          auto-optimise-store = true;

          substituters = [
            "https://cache.nixos.org"
            "https://cachix.cachix.org"
            "https://nixpkgs.cachix.org"
            "https://nix-community.cachix.org"
          ];

          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
            "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
        };

        nix.gc = {
          automatic = lib.mkDefault true;
          dates = lib.mkDefault "weekly";
          options = lib.mkDefault "--delete-older-than 7d";
        };
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      flake = {
        nixosConfigurations = {
          adam = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs pkgsUnstable; };
            modules = [
              commonNixConfig
              disko.nixosModules.disko
              inputs.home-manager.nixosModules.home-manager
              inputs.autoaspm.nixosModules.default
              inputs.sops-nix.nixosModules.sops
              inputs.vpn-confinement.nixosModules.default
              ./machines/nixos/adam/configuration.nix
              (import ./overlays inputs)
            ];
          };
          tabris = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs pkgsUnstable; };
            modules = [
              commonNixConfig
              inputs.nixos-wsl.nixosModules.default
              inputs.home-manager.nixosModules.home-manager
              ./machines/nixos/tabris/configuration.nix
              (import ./overlays inputs)
            ];
          };
          lilith = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs pkgsUnstable; };
            modules = [
              commonNixConfig
              inputs.disko.nixosModules.disko
              inputs.lanzaboote.nixosModules.lanzaboote
              inputs.home-manager.nixosModules.home-manager
              ./machines/nixos/lilith/configuration.nix
              (import ./overlays inputs)
            ];
          };
        };
      };
    };
}

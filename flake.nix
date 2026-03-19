{
  description = "NixOS configurations for homelab and servers";

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
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable?shallow=true";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11?shallow=true";
    configarr = {
      url = "github:raydak-labs/configarr";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-unstable";
    };
    # NixOS infrastructure
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # System configuration management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    autoaspm = {
      url = "git+https://git.notthebe.ee/notthebee/AutoASPM";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = inputs @ {flake-parts, ...}: let
    unstable = inputs."nixpkgs-unstable";
    stable = inputs."nixpkgs-stable";
    lib = unstable.lib;

    # Shared modules applied to all hosts
    sharedModules = [
      ./machines/nixos
      inputs.home-manager.nixosModules.home-manager
    ];

    mkSpecialArgs = {
      inherit inputs;
    };

    # Host definitions with their specific modules and system architecture
    hosts = {
      adam = {
        system = "x86_64-linux";
        channel = "unstable";
        modules = [
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          inputs.autoaspm.nixosModules.default
          ./modules/homelab
          ./machines/nixos/adam/configuration.nix
        ];
      };
      tabris = {
        system = "x86_64-linux";
        channel = "unstable";
        modules = [
          inputs.nixos-wsl.nixosModules.default
          ./machines/nixos/tabris/configuration.nix
        ];
      };
      lilith = {
        system = "x86_64-linux";
        channel = "stable";
        modules = [
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          ./machines/nixos/lilith/configuration.nix
        ];
      };
      sachiel = {
        system = "x86_64-linux";
        channel = "unstable";
        modules = [
          inputs.disko.nixosModules.disko
          ./machines/nixos/sachiel/configuration.nix
        ];
      };
    };

    # Build NixOS configurations from host definitions
    mkSystem = lib.mapAttrs (
      _: host: let
        pkgsInput =
          if host.channel == "stable"
          then stable
          else unstable;
      in
        pkgsInput.lib.nixosSystem {
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

      perSystem = {system, ...}: let
        pkgs = import unstable {inherit system;};
      in {
        formatter = pkgs.writeShellApplication {
          name = "nix-fmt";
          runtimeInputs = [pkgs.alejandra];
          text = ''
            exec alejandra . "$@"
          '';
        };
      };

      flake = {
        nixosConfigurations = mkSystem hosts;
      };
    };
}

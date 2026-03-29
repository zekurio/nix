{
  description = "NixOS configurations for homelab, servers, and workstations";

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
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    danksearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    helium-browser = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    t3code = {
      url = "github:omarcresp/t3code-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = {
    self,
    flake-parts,
    ...
  } @ inputs: let
    unstable = inputs."nixpkgs-unstable";
    lib = unstable.lib;
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./modules/hosts
      ];

      systems = ["x86_64-linux"];

      _module.args = {
        inherit inputs lib self;
      };

      perSystem = {system, ...}: let
        pkgs = import unstable {inherit system;};
        desktopPackages = import ./modules/desktop/packages.nix {
          inherit lib pkgs;
        };
      in {
        formatter = pkgs.writeShellApplication {
          name = "nix-fmt";
          runtimeInputs = [pkgs.alejandra];
          text = ''
            exec alejandra . "$@"
          '';
        };

        packages = desktopPackages;
      };

      flake = {};
    };
}

{
  description = "Nix configurations for my NixOS hosts and macOS";

  # nixConfig is parsed statically and cannot import modules/nix/default.nix;
  # keep this list in sync with that module by hand.
  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://cachix.cachix.org"
      "https://nixpkgs.cachix.org"
      "https://nix-community.cachix.org"
      "https://cache.garnix.io"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    download-buffer-size = 1073741824;
  };

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable?shallow=true";
    # Only consumed by modules/nixpkgs/overlays/vaultwarden; remove both once
    # nixos-unstable carries vaultwarden >= 1.37.0.
    nixpkgs-small.url = "github:nixos/nixpkgs/nixos-unstable-small?shallow=true";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-unstable";
    };
    import-tree.url = "github:vic/import-tree";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    llm-agents.url = "github:numtide/llm-agents.nix";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    blitzcrank = {
      url = "github:zekurio/blitzcrank";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    alloy = {
      url = "github:zekurio/alloy/382349ad3857cff41eccb30f8f143e5e429f8706";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    anvil = {
      url = "github:zekurio/anvil";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    configarr = {
      url = "github:raydak-labs/configarr/v1.30.0";
      inputs.flake-parts.follows = "flake-parts";
    };
    calthing = {
      url = "github:zekurio/calthing";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    inviterr = {
      url = "github:zekurio/inviterr";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    costthing = {
      url = "github:zekurio/costthing";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    autoaspm = {
      url = "git+https://git.notthebe.ee/notthebee/AutoASPM";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    cpu-microcodes = {
      url = "github:platomav/CPUMicrocodes/0be0bd7b6a3ec1f1b59562729f1ce14b9569b697";
      flake = false;
    };
    ucodenix = {
      url = "github:e-tho/ucodenix";
      inputs.cpu-microcodes.follows = "cpu-microcodes";
    };
  };

  # Dendritic layout: every file under ./modules is a flake-parts module and is
  # discovered by import-tree, so this file only wires inputs and systems.
  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.flake-parts.flakeModules.modules
        (inputs.import-tree ./modules)
      ];

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem = {system, ...}: let
        pkgs = import inputs.nixpkgs-unstable {inherit system;};
      in {
        formatter = pkgs.writeShellApplication {
          name = "nix-fmt";
          runtimeInputs = [pkgs.alejandra];
          text = ''
            # Format the whole tree when `nix fmt` is called without paths,
            # but honour the paths it passes when it does.
            if [ "$#" -eq 0 ]; then
              set -- .
            fi
            exec alejandra "$@"
          '';
        };
      };
    };
}

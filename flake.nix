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
      "https://nyx-cache.chaotic.cx/"
      "https://zed.cachix.org"
      "https://zekurio.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "zekurio.cachix.org-1:mv0mACvSLZtBkXXh5YDPPXmFBJ/eO+VkSzep6LJZrAg="
    ];
    download-buffer-size = 1073741824;
  };

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable?shallow=true";
    # Stable channel for ramiel, the publicly exposed edge host: less churn and
    # security backports where freshness matters least (its workload runs in
    # containers anyway).
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05?shallow=true";
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
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Chaotic supplies cached CachyOS kernels and current Proton builds. Keep
    # its own nixpkgs pin: matching that pin is what makes its cache usable.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    # Upstream only publishes its moving nightly tag to zed.cachix.org; using
    # main here would compile Zed and its Rust dependency graph locally.
    zed.url = "github:zed-industries/zed/nightly";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-linux-builder.url = "github:input-output-hk/nix-linux-builder";
    # Shared skills for Codex and OpenCode, consumed as a plain source tree.
    agent-stuff = {
      url = "github:zekurio/agent-stuff";
      flake = false;
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    blitzcrank = {
      url = "github:zekurio/blitzcrank";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    alloy = {
      url = "github:zekurio/alloy";
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

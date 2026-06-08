{
  description = "NixOS configurations for homelab and servers";

  inputs.self.lfs = true;

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://cachix.cachix.org"
      "https://nixpkgs.cachix.org"
      "https://nix-community.cachix.org"
      "https://zekurio.cachix.org"
      "https://cache.garnix.io"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "zekurio.cachix.org-1:QfL4gb2uCVEmSOOx4fLGDpygY1ycH5oUS1nteYTAgHc="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    download-buffer-size = 1073741824;
  };

  # Flake inputs: external dependencies and frameworks
  inputs = {
    # Core dependencies
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable?shallow=true";
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
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    herdr = {
      url = "github:ogulcancelik/herdr/v0.6.8";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # WSL host
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
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

  outputs = {flake-parts, ...} @ inputs: let
    unstable = inputs."nixpkgs-unstable";
    lib = unstable.lib;
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./modules/hosts
      ];

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

      flake = {};
    };
}

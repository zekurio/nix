{
  description = "Nix configurations for my NixOS hosts and macOS";

  # nixConfig is parsed statically and cannot import modules/common/nix.nix;
  # keep this list in sync with that module by hand.
  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://cachix.cachix.org"
      "https://nixpkgs.cachix.org"
      "https://nix-community.cachix.org"
      "https://nyx-cache.chaotic.cx/"
      "https://zekurio.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
      "zekurio.cachix.org-1:mv0mACvSLZtBkXXh5YDPPXmFBJ/eO+VkSzep6LJZrAg="
    ];
    download-buffer-size = 1073741824;
  };

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    import-tree.url = "github:vic/import-tree";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Claude Code, Codex, OpenCode and T3 Code. The weekly flake.lock PR moves
    # the pin; agents-update runs ahead of it and repeats this URL.
    # Keep its own nixpkgs pin: cache.numtide.com only serves builds made
    # against that pin.
    llm-agents.url = "github:numtide/llm-agents.nix";
    # Shared agent skills.
    agent-stuff = {
      url = "github:zekurio/agent-stuff";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    jellium-desktop = {
      url = "github:Galvanizedneuron/jellium-desktop-nixos-temporary-flake";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Keep Chaotic's nixpkgs pin so its CachyOS kernel and Proton builds
    # match the binaries available in its cache.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Ghostty main for KWin's ext-background-effect blur; 1.3.1 only speaks the
    # org_kde_kwin_blur protocol that Plasma 6.8 dropped. ghostty.cachix.org
    # holds no builds of main, so it builds locally against our nixpkgs.
    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-linux-builder.url = "github:input-output-hk/nix-linux-builder";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    blitzcrank = {
      url = "github:zekurio/blitzcrank";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    orianna = {
      url = "github:zekurio/orianna";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    alloy = {
      url = "github:zekurio/alloy/v0.1.1";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    configarr = {
      # v1.30.2 pins the recyclarr config-templates repo to the last
      # includes/-compatible revision; upstream v8 removed them and crashed
      # every run (raydak-labs/configarr#504).
      url = "github:raydak-labs/configarr/v1.30.2";
    };
    inviterr = {
      url = "github:zekurio/inviterr";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    vrouter = {
      url = "github:zekurio/vrouter";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Keep fluxer-nix's own nixpkgs pin. No cache serves its packages, and
    # following ours would rebuild every Fluxer service, with full LTO, on
    # each weekly flake.lock bump.
    fluxer-nix.url = "github:zekurio/fluxer-nix";
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

  # Every .nix file under a directory of ./modules is a module of that
  # directory's class, so a system is the import-tree of its directories.
  # import-tree skips _-prefixed files, which are package expressions for
  # callPackage.
  outputs = inputs @ {
    nixpkgs-unstable,
    nix-darwin,
    import-tree,
    ...
  }: let
    forAllSystems = nixpkgs-unstable.lib.genAttrs [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    pkgsFor = system: import nixpkgs-unstable {inherit system;};
    specialArgs = {inherit inputs;};
  in {
    nixosConfigurations = {
      adam = nixpkgs-unstable.lib.nixosSystem {
        inherit specialArgs;
        modules = [
          (import-tree [
            ./modules/common
            ./modules/nixos
            ./modules/hosts/adam
            ./modules/homelab
          ])
        ];
      };

      lilith = nixpkgs-unstable.lib.nixosSystem {
        inherit specialArgs;
        modules = [
          (import-tree [
            ./modules/common
            ./modules/nixos
            ./modules/hosts/lilith
          ])
        ];
      };
    };

    darwinConfigurations.sachiel = nix-darwin.lib.darwinSystem {
      inherit specialArgs;
      modules = [
        (import-tree [
          ./modules/common
          ./modules/darwin
          ./modules/hosts/sachiel
        ])
      ];
    };

    # The user modules of both platforms import this into Home Manager.
    homeModules.zekurio = import-tree ./modules/home/zekurio;

    packages = forAllSystems (system:
      import ./packages/agents.nix {
        inherit inputs;
        pkgs = pkgsFor system;
      });

    formatter = forAllSystems (system: let
      pkgs = pkgsFor system;
    in
      pkgs.writeShellApplication {
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
      });
  };
}

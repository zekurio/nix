{
  inputs,
  lib,
  pkgs,
  ...
}: let
  username = "zekurio";
  homeDirectory = "/Users/${username}";
in {
  imports = [
    ../../nixpkgs
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";

  system = {
    primaryUser = username;
    stateVersion = 6;
  };
  # nix-darwin master still passes the removed --toc-depth flag to
  # nixos-render-docs from current nixpkgs, breaking darwin-manual-html.
  # Skip the HTML manual and the uninstaller (whose embedded default system
  # also builds the manual) until upstream switches to --sidebar-depth.
  documentation.doc.enable = false;
  system.tools.darwin-uninstaller.enable = false;

  programs.fish.enable = true;
  environment.shells = [pkgs.fish];
  users.knownUsers = [username];
  users.users.${username} = {
    uid = 501;
    gid = 20;
    description = "Michael";
    home = homeDirectory;
    shell = pkgs.fish;
  };

  # Vanilla (upstream) Nix, managed declaratively by nix-darwin. These settings
  # are written to /etc/nix/nix.conf on activation.
  nix = {
    enable = true;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@admin"
        username
      ];
      substituters = [
        "https://cache.nixos.org/"
        "https://cache.numtide.com"
        "https://cachix.cachix.org"
        "https://nixpkgs.cachix.org"
        "https://nix-community.cachix.org"
        "https://cache.garnix.io"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
        "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
      auto-optimise-store = true;
    };
  };

  # Leave macOS's own /etc/pam.d/sudo_local in place; don't let nix-darwin manage
  # it. Setting the option (vs. forcing the etc file off) also removes the stale
  # `include sudo_local` line nix-darwin would otherwise add to /etc/pam.d/sudo.
  security.pam.services.sudo_local.enable = false;

  nix-homebrew = {
    enable = true;
    enableFishIntegration = true;
    user = username;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs;};

    users.${username} = {
      home = {
        inherit username homeDirectory;
      };

      imports = [
        ../../home/zekurio
      ];
    };
  };
}

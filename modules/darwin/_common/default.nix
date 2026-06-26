{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../nixpkgs
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";

  system = {
    primaryUser = "zekurio";
    stateVersion = 6;
  };

  programs.fish.enable = true;
  environment.shells = [pkgs.fish];
  users.users.zekurio = {
    home = "/Users/zekurio";
    shell = pkgs.fish;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "@admin"
      "zekurio"
    ];
    substituters = [
      "https://cache.nixos.org/"
      "https://cache.numtide.com"
      "https://cachix.cachix.org"
      "https://nixpkgs.cachix.org"
      "https://nix-community.cachix.org"
      "https://zekurio.cachix.org"
      "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "zekurio.cachix.org-1:QfL4gb2uCVEmSOOx4fLGDpygY1ycH5oUS1nteYTAgHc="
      "zekurio.cachix.org-1:esutyOTeL/aict5fKEf0Zm4fHazmwGapCLfjekfEv9o="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    auto-optimise-store = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs;};

    users.zekurio = {
      home = {
        username = "zekurio";
        homeDirectory = "/Users/zekurio";
      };

      imports = [
        inputs.catppuccin.homeModules.catppuccin
        ../../home/zekurio
      ];
    };
  };
}

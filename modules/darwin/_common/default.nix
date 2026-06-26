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

  nix = {
    enable = false;
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
        "https://zekurio.cachix.org"
        "https://cache.garnix.io"
        "https://zed.cachix.org"
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
        "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      ];
      auto-optimise-store = true;
    };
  };

  environment.etc."pam.d/sudo_local".enable = lib.mkForce false;

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

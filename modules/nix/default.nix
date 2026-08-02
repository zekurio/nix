# Nix daemon settings shared by every platform.
#
# The substituter list is duplicated in flake.nix's `nixConfig`, which is
# parsed statically and cannot import this file. Keep both copies in sync.
{lib, ...}: let
  substituters = [
    "https://cache.nixos.org/"
    "https://cache.numtide.com"
    "https://cachix.cachix.org"
    "https://nixpkgs.cachix.org"
    "https://nix-community.cachix.org"
    "https://nyx-cache.chaotic.cx/"
    "https://zed.cachix.org"
    "https://zekurio.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
    "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
    "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
    "zekurio.cachix.org-1:mv0mACvSLZtBkXXh5YDPPXmFBJ/eO+VkSzep6LJZrAg="
  ];

  common = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    inherit substituters;
  };
in {
  flake.modules.nixos.base.nix.settings =
    common
    // {
      inherit trusted-public-keys;
    };

  flake.modules.darwin.base.nix.settings =
    common
    // {
      # nix-darwin contributes cache.nixos.org at the same priority; mkBefore
      # keeps our entries first in /etc/nix/nix.conf.
      trusted-public-keys = lib.mkBefore trusted-public-keys;
    };
}

{ lib, ... }:

{
  imports = [ ];

  # Common Nix configuration
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = lib.mkForce "--delete-older-than 7d";
    };
    settings = {
      auto-optimise-store = true;
    };
  };
}

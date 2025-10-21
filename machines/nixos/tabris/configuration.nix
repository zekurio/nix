{ config, pkgs, ... }:

{
  imports = [
    ../../../modules/wsl
    ../../../modules/home-manager
  ];

  # WSL Configuration
  wsl.enable = true;

  # Home Manager Configuration
  modules.homeManager = {
    enable = true;
    base.enable = true;
    git.enable = true;
  };



  # System configuration
  networking.hostName = "tabris";
  time.timeZone = "Europe/Vienna";
  security.sudo.wheelNeedsPassword = false;
  nixpkgs.config.allowUnfree = true;
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  # System state version
  system.stateVersion = "25.05";
}

{
  lib,
  pkgs,
  ...
}: let
  mainUser = "zekurio";
in {
  networking.hostName = "tabris";

  wsl = {
    enable = true;
    defaultUser = mainUser;
    startMenuLaunchers = true;
    wslConf.network.hostname = "tabris";
  };

  programs.nix-ld.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    wsl2-ssh-agent
  ];

  home-manager.users.${mainUser}.imports = [
    ../../home/zekurio/opencode.nix
    ./home.nix
  ];

  system.stateVersion = "25.05";
}

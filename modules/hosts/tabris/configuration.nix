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
    docker-desktop.enable = true;
    interop.includePath = true;
    ssh-agent.enable = true;
  };

  programs.nix-ld.enable = lib.mkForce false;

  users.users = {
    root.linger = true;
    ${mainUser}.linger = true;
  };

  systemd.tmpfiles.rules = [
    "L+ /usr/bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];

  system.stateVersion = "25.05";
}

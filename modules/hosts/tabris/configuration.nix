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
    # Use Docker from Docker Desktop on Windows.
    docker-desktop.enable = true;
    # Expose the Windows PATH so interop binaries (op-ssh-sign-wsl, docker) work.
    interop.includePath = true;
    # Bridge ssh-agent to the Windows OpenSSH agent (backed by 1Password).
    ssh-agent.enable = true;
  };

  # nix-ld conflicts with WSL interop binaries; _common enables it by default.
  programs.nix-ld.enable = lib.mkForce false;

  # Keep user services (ssh-agent bridge) alive without an active login session.
  users.users = {
    root.linger = true;
    ${mainUser}.linger = true;
  };

  # Some Windows-side tooling expects a /usr/bin/bash to exist.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];

  system.stateVersion = "25.05";
}

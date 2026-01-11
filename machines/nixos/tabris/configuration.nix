{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../default.nix
  ];

  system.stateVersion = "25.05";

  # Disable channels for flake-only setup
  nix.channel.enable = false;

  wsl = {
    enable = true;
    defaultUser = "zekurio";
  };

  modules.virtualization.enable = true;

  # WSL2 SSH agent bridge to Windows ssh-agent.exe
  # Requires Windows OpenSSH agent service to be running
  home-manager.users.zekurio = {
    home.packages = [pkgs.wsl2-ssh-agent];

    programs.zsh.initContent = lib.mkAfter ''
      # Initialize wsl2-ssh-agent for Windows SSH agent forwarding
      if [[ -z "$SSH_AUTH_SOCK" ]]; then
        export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
        if ! ${pkgs.socat}/bin/socat -u OPEN:/dev/null UNIX-CONNECT:"$SSH_AUTH_SOCK" &>/dev/null; then
          rm -f "$SSH_AUTH_SOCK"
          (setsid ${pkgs.wsl2-ssh-agent}/bin/wsl2-ssh-agent -socket "$SSH_AUTH_SOCK" &>/dev/null &)
        fi
      fi
    '';
  };
}

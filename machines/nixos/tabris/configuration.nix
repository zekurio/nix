{pkgs, lib, ...}: {
  networking.hostName = "tabris";

  modules.virtualization.enable = true;

  wsl = {
    enable = true;
    defaultUser = "zekurio";
  };

  environment = {
    shells = lib.mkAfter [
      pkgs.bashInteractive
      pkgs.nushell
    ];

    systemPackages = [
      pkgs.wsl2-ssh-agent
    ];

    sessionVariables = {
      SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/wsl2-ssh-agent.sock";
    };
  };

  users.defaultUserShell = lib.mkForce pkgs.bashInteractive;
  users.users.zekurio.shell = lib.mkForce pkgs.bashInteractive;

  home-manager.users.zekurio.programs.bash = {
    enable = true;
    initExtra = ''
      if [[ $- == *i* ]] && [[ ''${SHLVL:-0} -eq 1 ]] && command -v nu >/dev/null 2>&1; then
        exec nu
      fi
    '';
  };

  systemd.user.services.wsl2-ssh-agent = {
    description = "WSL2 SSH Agent Bridge";
    after = ["network.target"];
    wantedBy = ["default.target"];
    serviceConfig = {
      ExecStart = "${pkgs.wsl2-ssh-agent}/bin/wsl2-ssh-agent --verbose --foreground --socket=%t/wsl2-ssh-agent.sock";
      Restart = "on-failure";
    };
  };

  system.stateVersion = "25.05";
}

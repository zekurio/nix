{pkgs, ...}: {
  home = {
    packages = with pkgs; [
      wsl2-ssh-agent
    ];
    sessionVariables.SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/wsl2-ssh-agent.sock";
  };

  systemd.user.services.wsl2-ssh-agent = {
    Unit.Description = "WSL2 SSH agent bridge";

    Service = {
      ExecStart = "${pkgs.wsl2-ssh-agent}/bin/wsl2-ssh-agent -foreground -socket %t/wsl2-ssh-agent.sock";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = ["default.target"];
  };
}

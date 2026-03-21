{pkgs, ...}: {
  networking.hostName = "tabris";

  modules.virtualization.enable = true;
  home-manager.users.zekurio.modules.hm.shell.packages.dev.enable = true;

  wsl = {
    enable = true;
    defaultUser = "zekurio";
  };

  environment = {
    systemPackages = [
      pkgs.wsl2-ssh-agent
    ];

    sessionVariables = {
      SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/wsl2-ssh-agent.sock";
    };
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

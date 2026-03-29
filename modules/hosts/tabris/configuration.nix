{
  pkgs,
  lib,
  ...
}: {
  networking.hostName = "tabris";

  modules.virtualization.enable = true;

  wsl = {
    enable = true;
    defaultUser = "zekurio";
  };

  environment = {
    shells = lib.mkAfter [
      pkgs.bashInteractive
      pkgs.zsh
    ];

    systemPackages = [
      pkgs.wsl2-ssh-agent
    ];

    sessionVariables = {
      SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/wsl2-ssh-agent.sock";
    };
  };

  users.defaultUserShell = lib.mkForce pkgs.zsh;
  users.users.zekurio.shell = lib.mkForce pkgs.zsh;

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

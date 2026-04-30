{
  lib,
  pkgs,
  ...
}: {
  networking.hostName = "tabris";

  modules.virtualization.enable = true;

  wsl = {
    enable = true;
    defaultUser = "zekurio";
    startMenuLaunchers = true;

    docker-desktop.enable = false;

    wslConf = {
      automount.root = "/mnt";
      network.generateHosts = true;
      network.generateResolvConf = true;
    };
  };

  environment.systemPackages = with pkgs; [
    curl
    htop
    wget
    wsl2-ssh-agent
  ];

  environment.variables.SSH_AUTH_SOCK = "/mnt/wsl/ssh-agent.sock";

  systemd.user.services.ssh-agent-bridge = {
    description = "Windows SSH agent proxy";
    path = with pkgs; [
      coreutils
      wsl2-ssh-agent
    ];
    wantedBy = ["default.target"];
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /mnt/wsl"
        "${pkgs.coreutils}/bin/rm -f /mnt/wsl/ssh-agent.sock"
      ];
      ExecStart = "${lib.getExe pkgs.wsl2-ssh-agent} -foreground -socket /mnt/wsl/ssh-agent.sock -pipename openssh-ssh-agent";
      Type = "simple";
      Restart = "always";
      RestartSec = "5";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  home-manager.users.zekurio = {...}: {
    home.file.".ssh/.keep".text = "";

    programs.ssh = {
      enable = true;
      extraConfig = ''
        IdentityAgent /mnt/wsl/ssh-agent.sock
      '';
    };
  };

  system.stateVersion = "25.05";
}

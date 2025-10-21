{ pkgs, ... }:

{
  imports = [
    ../../../modules/home-manager
  ];

  # WSL-specific configuration
  wsl = {
    enable = true;
    defaultUser = "zekurio";
    startMenuLaunchers = true;

    # Enable native Docker support
    docker-desktop.enable = false;

    # WSL-specific settings
    wslConf = {
      automount.root = "/mnt";
      network.generateHosts = true;
      network.generateResolvConf = true;
    };
  };

  # Networking
  networking.hostName = "tabris";

  # Nix configuration
  nixpkgs.config.allowUnfree = true;

  # Enable home-manager modules for user setup
  modules.homeManager.base.enable = true;
  modules.homeManager.git.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    wget
    curl
    htop
    socat
    wslu  # For wslvar to get Windows username
  ];

  # Windows SSH Agent integration
  environment.variables = {
    SSH_AUTH_SOCK = "/mnt/wsl/ssh-agent.sock";
  };

  # Configure systemd user service for SSH agent forwarding
  # This bridges the Windows SSH agent (running in Windows) to WSL
  # Make sure OpenSSH Authentication Agent service is running in Windows
  # npiperelay.exe must be installed on Windows (via scoop, winget, or chocolatey)
  systemd.user.services.ssh-agent-bridge = {
    description = "Windows SSH agent proxy";
    path = [ pkgs.wslu pkgs.coreutils pkgs.bash pkgs.socat ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /mnt/wsl"
        "${pkgs.coreutils}/bin/rm -f /mnt/wsl/ssh-agent.sock"
      ];
      ExecStart = "${pkgs.writeShellScript "ssh-agent-bridge" ''
        set -x  # Enable debug output

        # Get Windows username using wslvar
        WIN_USER="$(${pkgs.wslu}/bin/wslvar USERNAME 2>/dev/null || echo $USER)"

        # Check common npiperelay locations
        NPIPE_PATHS=(
          "/mnt/c/Users/$WIN_USER/scoop/apps/npiperelay/current/npiperelay.exe"
          "/mnt/c/Users/$WIN_USER/AppData/Local/Microsoft/WinGet/Links/npiperelay.exe"
          "/mnt/c/ProgramData/chocolatey/bin/npiperelay.exe"
        )

        NPIPE_PATH=""
        for path in "''${NPIPE_PATHS[@]}"; do
          echo "Checking npiperelay at: $path"
          if [ -f "$path" ]; then
            NPIPE_PATH="$path"
            break
          fi
        done

        if [ -z "$NPIPE_PATH" ]; then
          echo "npiperelay.exe not found in expected locations!"
          echo "Please install npiperelay on Windows using:"
          echo "  - scoop install npiperelay"
          echo "  - winget install npiperelay"
          echo "  - choco install npiperelay"
          exit 1
        fi

        echo "Using npiperelay from: $NPIPE_PATH"

        exec ${pkgs.socat}/bin/socat -d UNIX-LISTEN:/mnt/wsl/ssh-agent.sock,fork,mode=600 \
          EXEC:"$NPIPE_PATH -ei -s //./pipe/openssh-ssh-agent",nofork
      ''}";
      Type = "simple";
      Restart = "always";
      RestartSec = "5";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.user.services.ssh-agent-bridge.serviceConfig.RuntimeDirectory = "ssh-agent";

  # Configure home-manager for SSH
  home-manager.users.zekurio = { ... }: {
    home.file.".ssh/.keep".text = "";

    programs.ssh = {
      enable = true;
      extraConfig = ''
        # Use Windows SSH Agent
        IdentityAgent /mnt/wsl/ssh-agent.sock
      '';
    };
  };

  # Time zone
  time.timeZone = "Europe/Vienna";

  # DO NOT TOUCH THIS
  system.stateVersion = "25.05";
}

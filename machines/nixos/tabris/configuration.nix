{ lib
, pkgs
, ...
}:
let
  inherit (lib) mkDefault;
  wslUser = "zekurio";
in
{
  wsl = {
    enable = true;
    defaultUser = wslUser;
    startMenuLaunchers = true;
    tarball.configPath = ../../..;
  };

  networking = {
    hostName = "tabris";
    useDHCP = mkDefault true;
    firewall.enable = mkDefault false;
  };

  time.timeZone = mkDefault "Europe/Vienna";

  security.sudo.wheelNeedsPassword = mkDefault false;

  environment = {
    variables =
      let
        gccLibPath = lib.makeLibraryPath [ pkgs.stdenv.cc.cc ];
      in
      {
        LD_LIBRARY_PATH = "${gccLibPath}:/usr/lib/wsl/lib:$LD_LIBRARY_PATH";
        SSH_AUTH_SOCK = "/mnt/wsl/ssh-agent.sock";
      };
    shellAliases = {
      rebuild-tabris = "sudo nixos-rebuild switch --flake .#tabris";
      tabris-tarball = "nix build .#nixosConfigurations.tabris.config.system.build.tarballBuilder";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.ssh.startAgent = false;

  services.openssh = {
    enable = mkDefault true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  systemd.user.services.ssh-agent-proxy = {
    description = "Windows SSH agent proxy";
    path = [ pkgs.wslu pkgs.coreutils pkgs.bash pkgs.socat ];
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /mnt/wsl"
        "${pkgs.coreutils}/bin/rm -f /mnt/wsl/ssh-agent.sock"
      ];
      ExecStart = "${pkgs.writeShellScript "ssh-agent-proxy" ''
        set -euo pipefail
        set -x

        WIN_USER="$("${pkgs.wslu}/bin/wslvar" USERNAME 2>/dev/null || echo "$USER")"

        NPIPE_PATHS=(
          "/mnt/c/ProgramData/chocolatey/bin/npiperelay.exe"
          "/mnt/c/Users/$WIN_USER/scoop/apps/npiperelay/current/npiperelay.exe"
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
          exit 1
        fi

        echo "Using npiperelay from: $NPIPE_PATH"

        exec ${pkgs.socat}/bin/socat -d UNIX-LISTEN:/mnt/wsl/ssh-agent.sock,fork,mode=600 \
          EXEC:"$NPIPE_PATH -ei -s //./pipe/openssh-ssh-agent",nofork
      ''}";
      Restart = "always";
      RestartSec = 5;
      Type = "simple";
      RuntimeDirectory = "ssh-agent";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = [ "default.target" ];
  };
  modules.development.tooling.enable = mkDefault true;



  documentation.nixos.enable = mkDefault false;

  system.stateVersion = "25.05";
}

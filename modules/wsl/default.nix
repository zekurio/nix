{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.wsl;
in

{
  options.wsl = {
    enable = mkEnableOption "WSL configuration";
    defaultUser = mkOption {
      type = types.str;
      default = "nixos";
      description = "Default user for WSL";
    };
    interop.enable = mkEnableOption "WSL interop features" // { default = true; };
  };

  config = mkIf cfg.enable {
    # WSL-specific boot configuration
    boot = {
      loader.grub.enable = false;
      isContainer = true;
    };

    # Enable systemd in WSL
    systemd.package = pkgs.systemd;
    systemd.sysctl."fs.inotify.max_user_watches" = mkDefault 524288;

    # Networking configuration for WSL
    networking = {
      useDHCP = false;
      nameservers = [ "1.1.1.1" "1.0.0.1" ];
    };

    # WSL interoperability
    environment.variables = mkIf cfg.interop.enable {
      DISPLAY = ":0";
      LIBGL_ALWAYS_INDIRECT = "1";
    };

    # Basic system packages for WSL
    environment.systemPackages = with pkgs; [
      curl
      wget
      git
      vim
      htop
      less
      man-pages
    ];

    # Services configuration
    services = {
      openssh.enable = mkDefault false;
    };

    # File systems - WSL uses Windows host filesystem
    fileSystems."/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=50%" ];
    };

    # WSL-specific system configuration
    system.stateVersion = mkDefault "25.05";

    # Disable root password in WSL
    security.sudo.wheelNeedsPassword = false;

    # Enable user namespace for unprivileged container operations
    security.unprivilegedUsernsClone = true;

    # Systemd user services
    systemd.user.services = mkIf cfg.interop.enable {
      "wsl-interop" = {
        description = "WSL Interoperability Bridge";
        partOf = [ "graphical-session.target" ];
        wantedBy = [ "default.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c 'echo WSL interop enabled'";
        };
      };
    };
  };
}

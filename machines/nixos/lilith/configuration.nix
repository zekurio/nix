{
  config,
  pkgs,
  inputs,
  modulesPath,
  lib,
  ...
}:
let
  mainUser = "zekurio";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ../default.nix
  ];

  # System Configuration
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [
      "kvm-amd"
      "zenpower"
      "it87"
    ];
    kernelParams = [
      "acpi_enforce_resources=lax"
      "amdgpu.ppfeaturemask=0xffffffff"
    ];
    extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    extraModprobeConfig = ''
      options it87 force_id=0x8628
    '';
    blacklistedKernelModules = [ "k10temp" ];
    loader = {
      timeout = 3;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = lib.mkForce false;
        configurationLimit = 3;
      };
    };
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  time.timeZone = "Europe/Vienna";

  # Hardware
  hardware = {
    enableRedistributableFirmware = true;

    # AMD CPU
    cpu.amd = {
      updateMicrocode = true;
      ryzen-smu.enable = true;
    };

    # AMD GPU
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        rocmPackages.clr.icd
      ];
    };
    amdgpu.overdrive.enable = true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Networking
  networking = {
    hostName = "lilith";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  # Storage & Filesystems
  fileSystems = {
    "/mnt/vault" = {
      device = "//192.168.0.2/vault";
      fsType = "cifs";
      options = [
        "credentials=/home/zekurio/.smb/creds"
        "vers=3.0"
        "iocharset=utf8"
        "uid=1000" # zekurio
        "gid=100" # users
        "_netdev"
        "noauto,x-systemd.automount"
      ];
    };

    "/mnt/media" = {
      device = "//192.168.0.2/media";
      fsType = "cifs";
      options = [
        "credentials=/home/zekurio/.smb/creds"
        "vers=3.0"
        "iocharset=utf8"
        "uid=1000"
        "gid=100"
        "_netdev"
        "noauto,x-systemd.automount"
      ];
    };

    "/mnt/datadrop" = {
      device = "//192.168.0.2/datadrop";
      fsType = "cifs";
      options = [
        "credentials=/home/zekurio/.smb/creds"
        "vers=3.0"
        "iocharset=utf8"
        "uid=1000"
        "gid=100"
        "_netdev"
        "noauto,x-systemd.automount"
      ];
    };
  };

  # Security
  security = {
    rtkit.enable = true; # Real-time scheduling for audio
    pam.services.greetd.enableGnomeKeyring = true;
  };

  # Services
  services = {
    # System
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # Hardware
    lact.enable = true; # AMD GPU control
    power-profiles-daemon.enable = true;
    blueman.enable = true;
    udisks2.enable = true;
    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    # Desktop
    gnome.gnome-keyring.enable = true;
    displayManager.dms-greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = "/home/${mainUser}";
    };

    # Audio
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      extraConfig.pipewire = {
        "10-clock-rate" = {
          "context.properties" = {
            "default.clock.rate" = 48000;
            "default.clock.allowed-rates" = [
              44100
              48000
              96000
            ];
            "default.clock.quantum" = 4096;
            "default.clock.min-quantum" = 2048;
            "default.clock.max-quantum" = 8192;
          };
        };
      };
    };
  };

  # Programs
  programs = {
    # Desktop
    niri.enable = true;
    dms-shell = {
      enable = true;
      quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
      systemd = {
        enable = true;
        restartIfChanged = true;
      };
      enableSystemMonitoring = true;
      enableClipboard = true;
      enableDynamicTheming = true;
      enableAudioWavelength = true;
      enableVPN = true;
    };

    _1password.enable = true;
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "zekurio" ];
    };

    coolercontrol.enable = true;

    # Gaming
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };
  };

  # Environment
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "gtk3";
    QT_QPA_PLATFORMTHEME_QT6 = "gtk3";
    XCURSOR_THEME = "BreezeX-RosePine-Linux";
    XCURSOR_SIZE = "32";
  };

  environment.systemPackages = with pkgs; [
    # System
    ryzen-monitor-ng
    lm_sensors
    xwayland-satellite
    cifs-utils
    udiskie
    wl-clip-persist
    sbctl

    # Desktop
    _1password-cli
    _1password-gui
    brave
    celluloid
    deezer-enhanced
    ghostty
    heroic
    jellyfin-desktop
    loupe
    nautilus
    papers
    protonplus
    vesktop
    zed-editor

    # Gaming
    mangohud

    # Theming
    adw-gtk3
    papirus-icon-theme
    kdePackages.breeze
    qt6Packages.qt6ct
    rose-pine-cursor
  ];

  fonts.packages = with pkgs; [
    inter
    fira-code
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    nerd-fonts.symbols-only
  ];

  # Virtualization
  modules.virtualization.enable = true;

  # Systemd
  systemd.services.greetd.environment = {
    XCURSOR_THEME = "BreezeX-RosePine-Linux";
    XCURSOR_SIZE = "32";
  };

  systemd.user.services = {
    udiskie = {
      description = "udiskie automounter for removable drives";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.udiskie}/bin/udiskie -a -n -s";
        Restart = "on-failure";
      };
    };
  };

  # XDG
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  system.stateVersion = "25.11"; # DO NOT CHANGE
}

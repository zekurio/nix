{
  config,
  pkgs,
  inputs,
  modulesPath,
  lib,
  ...
}: let
  mainUser = "zekurio";
  nfsServer = "192.168.0.2";
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ../default.nix
    inputs.dms.nixosModules.greeter
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
    extraModulePackages = [config.boot.kernelPackages.zenpower];
    extraModprobeConfig = ''
      options it87 force_id=0x8628
    '';
    blacklistedKernelModules = ["k10temp"];
    loader = {
      timeout = 3;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 3;
      };
    };
    # TODO: switch back to lanzaboote once ready
    # lanzaboote = {
    #   enable = true;
    #   pkiBundle = "/var/lib/sbctl";
    # };
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  # NFS mounts
  fileSystems = {
    "/mnt/vault" = {
      device = "${nfsServer}:/tank/vault";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
      ];
    };
    "/mnt/media" = {
      device = "${nfsServer}:/tank/media";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
      ];
    };
    "/mnt/downloads" = {
      device = "${nfsServer}:/mnt/downloads";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
      ];
    };
  };

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
      enable32Bit = true;
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
    nameservers = ["192.168.0.2"];
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
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

    accounts-daemon.enable = true;

    # Hardware
    lact.enable = true; # AMD GPU control
    power-profiles-daemon.enable = true;
    udisks2.enable = true;
    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    # Desktop
    gnome.gnome-keyring.enable = true;

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
            "default.clock.quantum" = 8192;
            "default.clock.min-quantum" = 4096;
            "default.clock.max-quantum" = 16384;
          };
        };
      };
    };
  };

  # Programs
  programs = {
    # Desktop
    niri.enable = true;
    dank-material-shell.greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = "/home/${mainUser}";
    };

    _1password.enable = true;
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = ["zekurio"];
    };

    coolercontrol.enable = true;

    # Gaming
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
  };

  # Environment
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
    MESA_SHADER_CACHE_MAX_SIZE = "12G";
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
    cifs-utils
    wl-clip-persist
    sbctl
  ];

  environment.etc = {
    "1password/custom_allowed_browsers" = {
      text = ''
        zen
      '';
      mode = "0755";
    };
  };

  fonts.packages = with pkgs; [
    inter
    fira-code
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    nerd-fonts.symbols-only
  ];

  # Modules
  home-manager.users.zekurio.modules.hm.desktop.enable = true;
  modules.virtualization.enable = true;

  # Systemd
  systemd.services.greetd.environment = {
    XCURSOR_THEME = "BreezeX-RosePine-Linux";
    XCURSOR_SIZE = "32";
  };

  systemd.user.services = {
    udiskie = {
      description = "udiskie automounter for removable drives";
      wantedBy = ["default.target"];
      serviceConfig = {
        ExecStart = "${pkgs.udiskie}/bin/udiskie -a -n -s";
        Restart = "on-failure";
      };
    };
  };

  # XDG
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };

  system.stateVersion = "25.11"; # DO NOT CHANGE
}

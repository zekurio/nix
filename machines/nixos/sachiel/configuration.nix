{
  config,
  pkgs,
  inputs,
  modulesPath,
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
    ];
    loader = {
      timeout = 3;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = false;
      limine = {
        enable = true;
        maxGenerations = 3;
        secureBoot.enable = true;
        style = {
          interface.resolution = "1920x1080";
          wallpapers = [../../../assets/limine.jpeg];
        };
        extraConfig = ''
          remember_last_entry: yes
        '';
      };
    };
    initrd = {
      systemd = {
        enable = true;
        tpm2.enable = true;
      };
      luks.devices.cryptroot = {
        crypttabExtraOpts = [
          "tpm2-device=auto"
          "tpm2-pcrs=7+11"
        ];
      };
    };
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

    # Hybrid graphics (AMD iGPU + NVIDIA dGPU)
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      open = false;
      nvidiaSettings = true;
      modesetting.enable = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      prime = {
        # TODO: replace with values from `lspci -D -d ::03xx` on sachiel
        amdgpuBusId = "PCI:0@0:0:0";
        nvidiaBusId = "PCI:1@0:0:0";
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Networking
  networking = {
    hostName = "sachiel";
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
    tpm2.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;
  };

  # Services
  services = {
    xserver.videoDrivers = [
      "amdgpu"
      "nvidia"
    ];

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
  };

  # Environment
  environment.sessionVariables = {
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
        helium
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
  home-manager.users.zekurio.modules.hm.desktop = {
    enable = true;
    keyboardLayout = "de";
  };
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

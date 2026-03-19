{
  config,
  inputs,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  mainUser = "zekurio";
  keyboardLayout = "eu";
  desktopConfigDir = ../../../config/sachiel;
  limineWallpaper = builtins.path {
    path = ../../../assets/limine.jpeg;
    name = "limine.jpeg";
  };
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ../default.nix
    inputs.dms.nixosModules.greeter
  ];

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
      grub.enable = false;
      systemd-boot.enable = false;
      limine = {
        enable = true;
        maxGenerations = 3;
        resolution = "2560x1440x32";
        secureBoot.enable = true;
        style = {
          interface.resolution = "2560x1440";
          wallpapers = [ limineWallpaper ];
          wallpaperStyle = "stretched";
          graphicalTerminal = {
            background = "FF000000";
            margin = 0;
            marginGradient = 0;
          };
        };
        extraConfig = ''
          remember_last_entry: yes
        '';
        extraEntries = ''
          /Windows 11
            protocol: efi
            path: guid(f09cfdee-f635-4992-9dbe-e7bd2c94e444):/EFI/Microsoft/Boot/Bootmgfw.efi
        '';
      };
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd = {
      updateMicrocode = true;
      ryzen-smu.enable = true;
    };
    graphics.extraPackages = with pkgs; [
      mesa
      rocmPackages.clr.icd
    ];
    graphics.enable = true;
    graphics.enable32Bit = true;
    amdgpu.overdrive.enable = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    i2c.enable = true;
  };

  networking = {
    hostName = "sachiel";
    nameservers = [ "192.168.0.2" ];
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  time.timeZone = "Europe/Vienna";

  security = {
    rtkit.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    accounts-daemon.enable = true;
    gnome.gnome-keyring.enable = true;
    lact.enable = true;
    hardware.openrgb = {
      enable = true;
      package = pkgs.openrgb-with-all-plugins;
      motherboard = "amd";
    };
    power-profiles-daemon.enable = true;

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

    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      openFirewall = true;
    };

    udisks2.enable = true;
  };

  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ mainUser ];
    };
    coolercontrol.enable = true;
    gamemode = {
      enable = true;
      settings = {
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          amd_performance_level = "high";
        };
        custom = {
          start = "${lib.getExe' pkgs.power-profiles-daemon "powerprofilesctl"} set performance";
          end = "${lib.getExe' pkgs.power-profiles-daemon "powerprofilesctl"} set balanced";
        };
      };
    };
    gamescope.enable = true;
    niri.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    dank-material-shell.greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = "/home/${mainUser}";
    };
  };

  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
    LIBVA_DRIVER_NAME = "radeonsi";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    MESA_SHADER_CACHE_MAX_SIZE = "12G";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    SSH_AUTH_SOCK = "/home/${mainUser}/.1password/agent.sock";
    XCURSOR_SIZE = "32";
    XCURSOR_THEME = "BreezeX-RosePine-Linux";
  };

  environment.systemPackages = with pkgs; [
    cifs-utils
    ddcutil
    lm_sensors
    nvtopPackages.amd
    openrgb-with-all-plugins
    pciutils
    ryzen-monitor-ng
    sbctl
    wl-clip-persist
  ];

  services.udev.packages = [ pkgs.openrgb-with-all-plugins ];

  environment.etc =
    let
      bravePolicies = builtins.toJSON {
        BraveRewardsDisabled = true;
        BraveWalletDisabled = true;
        BraveVPNDisabled = 1;
        BraveAIChatEnabled = false;
        NewTabPageLocation = "https://kagi.com";
        TorDisabled = true;
        PasswordManagerEnabled = false;
        BlockThirdPartyCookies = true;
        EnableDoNotTrack = true;
      };
    in
    {
      "1password/custom_allowed_browsers" = {
        text = ''
          zen
          brave
        '';
        mode = "0755";
      };

      "brave/policies/managed/workstation.json".text = bravePolicies;
      "opt/brave.com/brave/policies/managed/workstation.json".text = bravePolicies;
    };

  fonts.packages = with pkgs; [
    inter
    nerd-fonts.jetbrains-mono
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    nerd-fonts.symbols-only
  ];

  fileSystems = {
    "/mnt/vault" = {
      device = "192.168.0.2:/tank/vault";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
      ];
    };
    "/mnt/media" = {
      device = "192.168.0.2:/tank/media";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
      ];
    };
    "/mnt/downloads" = {
      device = "192.168.0.2:/mnt/downloads";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=600"
      ];
    };
  };

  modules.virtualization.enable = true;

  systemd = {
    services.greetd.environment = {
      XCURSOR_THEME = "BreezeX-RosePine-Linux";
      XCURSOR_SIZE = "32";
    };

    user = {
      services = {
        gcr-ssh-agent.enable = false;
        udiskie = {
          description = "udiskie automounter for removable drives";
          wantedBy = [ "default.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.udiskie}/bin/udiskie -a -n -s";
            Restart = "on-failure";
          };
        };
      };

      sockets.gcr-ssh-agent.enable = false;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  home-manager.users.${mainUser} = {
    imports = [ inputs.dms.homeModules.dank-material-shell ];

    home.packages = with pkgs; [
      brave
      _1password-cli
      _1password-gui
      celluloid
      feishin
      faugus-launcher
      heroic
      jellyfin-desktop
      loupe
      mangohud
      nautilus
      papers
      protonplus
      udiskie
      vesktop
      xwayland-satellite
      zed-editor
      adw-gtk3
      matugen
      papirus-icon-theme
      kdePackages.breeze
      libsForQt5.qt5ct
      qt6Packages.qt6ct
      rose-pine-cursor
    ];

    programs = {
      dank-material-shell = {
        enable = true;
        systemd = {
          enable = true;
          restartIfChanged = true;
        };
        enableSystemMonitoring = true;
        enableDynamicTheming = true;
        enableAudioWavelength = true;
        enableVPN = true;
      };

      kitty = {
        enable = true;
        shellIntegration.mode = null;
        settings = {
          font_size = 12.0;
          window_padding_width = 12;
          background_opacity = 1.0;
          background_blur = 32;
          hide_window_decorations = "yes";
          cursor_shape = "block";
          cursor_blink_interval = 1;
          scrollback_lines = 3000;
          copy_on_select = "yes";
          strip_trailing_spaces = "smart";
          tab_bar_style = "hidden";
          tab_bar_align = "left";
          shell_integration = "enabled";
        };
        keybindings = {
          "ctrl+shift+n" = "new_window";
          "ctrl+t" = "no_op";
          "ctrl+plus" = "change_font_size all +1.0";
          "ctrl+minus" = "change_font_size all -1.0";
          "ctrl+0" = "change_font_size all 0";
        };
        extraConfig = ''
          # Dank color generation
          include dank-tabs.conf
          include dank-theme.conf
        '';
      };

      ssh.matchBlocks."*" = {
        compression = true;
        identityAgent = "~/.1password/agent.sock";
      };
    };

    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME/Desktop";
      documents = "$HOME/Documents";
      download = "$HOME/Downloads";
      music = "$HOME/Music";
      pictures = "$HOME/Pictures";
      publicShare = "$HOME/Public";
      templates = "$HOME/Templates";
      videos = "$HOME/Videos";
    };

    xdg.configFile = {
      "matugen/config.toml".text = ''
        [config]

        [templates.zed]
        input_path = "~/.config/matugen/templates/zed-colors.json"
        output_path = "~/.config/zed/themes/matugen.json"
      '';

      "matugen/templates/zed-colors.json".source = desktopConfigDir + /matugen-templates/zed-colors.json;

      "niri/config.kdl".text = lib.replaceStrings [ "@keyboardLayout@" ] [ keyboardLayout ] (
        builtins.readFile (desktopConfigDir + /niri-config.kdl)
      );

      "MangoHud/MangoHud.conf".text = ''
        control=mangohud
        full
        cpu_temp
        gpu_temp
        ram
        vram
        io_read
        io_write
        arch
        gpu_name
        cpu_power
        gpu_power
        wine
        frametime
      '';
    };
  };

  system.stateVersion = "25.11";
}

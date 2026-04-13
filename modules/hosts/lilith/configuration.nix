{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  rocmEnv = pkgs.symlinkJoin {
    name = "rocm-combined";
    paths = with pkgs.rocmPackages; [
      clr
      hipblas
      rocblas
    ];
  };
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  networking = {
    hostName = "lilith";
    firewall.enable = true;
  };

  modules.desktop.enable = true;
  modules.gaming.enable = true;
  modules.virtualization.enable = true;

  home-manager.users.zekurio = {
    profiles.desktop.enable = true;
    profiles.dev.enable = true;
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  # Zen kernel for gaming/desktop performance
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [
      "kvm-amd"
      "it87"
      "zenpower"
    ];
    extraModprobeConfig = ''
      options it87 force_id=0x8628
    '';
    extraModulePackages = [config.boot.kernelPackages.zenpower];
    blacklistedKernelModules = ["k10temp"];
    kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"
      "acpi_enforce_resources=lax"
      "amdgpu.ppfeaturemask=0xffffffff"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      limine = {
        enable = true;
        maxGenerations = 3;
        resolution = "2560x1440x32";
        secureBoot.enable = true;
        style = {
          interface = {
            resolution = "2560x1440";
            brandingColor = 6; # OneDark cyan
          };
          wallpapers = [../../../assets/ublue.png];
          backdrop = "282c34";
          graphicalTerminal = {
            background = "FF282c34";
            foreground = "abb2bf";
            brightForeground = "abb2bf";
            brightBackground = "3e4452";
            palette = "282c34;e06c75;98c379;d19a66;61afef;c678dd;56b6c2;5c6370";
            brightPalette = "3e4452;e06c75;98c379;e5c07b;61afef;c678dd;56b6c2;abb2bf";
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
            path: boot():/EFI/Microsoft/Boot/Bootmgfw.efi
        '';
      };
    };
    initrd.verbose = false;
  };

  hardware = {
    enableRedistributableFirmware = true;
    firmware = [pkgs.linux-firmware];
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    cpu.amd = {
      updateMicrocode = true;
      ryzen-smu.enable = true;
    };
  };

  # Fan control
  programs.coolercontrol.enable = true;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  environment.systemPackages = with pkgs; [
    easyeffects
    deepfilternet
    lact
    lm_sensors
    sbctl
    usbutils
  ];

  systemd = {
    packages = [pkgs.lact];
    services = {
      coolercontrold.serviceConfig.ExecStartPre = pkgs.writeShellScript "coolercontrol-clear-password" ''
        config=/etc/coolercontrol/config.toml
        if [ -f "$config" ]; then
          sed -i '/^password\s*=/d' "$config"
        fi
      '';

      lactd.wantedBy = ["multi-user.target"];

      # Workaround: disable GPP0 ACPI wakeup to prevent spurious wakeups
      disable-gpp0-acpi-wakeup = {
        description = "Disable ACPI wake device GPP0";
        wantedBy = ["multi-user.target"];
        after = ["sysinit.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "disable-gpp0-acpi-wakeup" ''
            echo GPP0 > /proc/acpi/wakeup
          '';
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
  ];

  services = {
    fwupd.enable = true;
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  users.users.zekurio.extraGroups = ["networkmanager"];

  console.keyMap = "de";
  time.timeZone = "Europe/Vienna";

  # DO NOT TOUCH THIS
  system.stateVersion = "25.05";
}

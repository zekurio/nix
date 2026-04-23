{
  config,
  pkgs,
  modulesPath,
  ...
}: let
  mkWorkstationLimine = import ../_common/workstation/limine.nix;
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
    networkmanager.dns = "systemd-resolved";
  };

  services.resolved = {
    enable = true;
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
      limine =
        mkWorkstationLimine {
          resolution = "2560x1440x32";
          interfaceResolution = "2560x1440";
        }
        // {
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
    cpu.amd = {
      ryzen-smu.enable = true;
    };
  };

  # Fan control
  programs.coolercontrol.enable = true;

  environment.systemPackages = with pkgs; [
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

  # DO NOT TOUCH THIS
  system.stateVersion = "25.05";
}

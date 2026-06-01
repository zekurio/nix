{
  inputs,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  mainUser = "zekurio";
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
  ];

  networking.hostName = "lilith";

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    # active mode exposes the amd-pstate EPP interface that
    # power-profiles-daemon drives (and which backs KDE's power-profile
    # selector). guided/passive mode has no EPP, so PPD has nothing to switch
    # and interactive bursts ramp clocks too conservatively.
    "amd_pstate=active"
    # Required by LACT for AMD Overdrive controls (clocks/voltage,
    # extended power limits, and RDNA3+ fan control).
    "amdgpu.ppfeaturemask=0xffffffff"
  ];
  boot.kernelModules = [
    "kvm-amd"
  ];
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
    "amdgpu"
  ];

  hardware.cpu.amd.updateMicrocode = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  hardware.amdgpu = {
    opencl.enable = true;
    initrd.enable = true;
  };

  # Many HIP/ROCm applications look for libraries under /opt/rocm instead of
  # the Nix store. Provide the expected compatibility path while keeping the
  # actual ROCm components managed by Nix.
  systemd.tmpfiles.rules = [
    "L+ /opt/rocm - - - - ${rocmEnv}"
  ];

  # LACT daemon for overclocking/fan control
  services.lact.enable = true;
  environment.systemPackages = with pkgs; [
    clinfo
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
    sbctl
  ];

  catppuccin = {
    flavor = "frappe";
    accent = "blue";
    limine.enable = true;
  };

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub.enable = false;
    systemd-boot.enable = false;
    limine = {
      enable = true;
      efiSupport = true;
      maxGenerations = 3;

      secureBoot.enable = true;

      # Reboot into the firmware's Windows Boot Manager entry instead of
      # chainloading a filesystem path. This avoids depending on a changing EFI
      # boot number or on the Windows ESP's filesystem UUID.
      extraEntries = ''
        /Windows
          protocol: efi_boot_entry
          entry: Windows Boot Manager
      '';

      style = {
        interface.branding = "";

        graphicalTerminal = {
          margin = 0;
          marginGradient = 0;
        };
      };
    };
  };

  # Let power-profiles-daemon own CPU power policy via amd-pstate EPP. In active
  # mode only performance/powersave governors exist, so do not pin a governor;
  # PPD switches the governor and EPP per selected profile.
  services.power-profiles-daemon.enable = lib.mkForce true;

  # tuned conflicts with power-profiles-daemon; keep it off so PPD owns policy.
  services.tuned.enable = lib.mkForce false;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  nix.settings.trusted-users = [mainUser];

  services.pipewire = {
    jack.enable = true;
  };

  programs.steam = {
    package = lib.mkForce (pkgs.steam.override {
      extraEnv = {
        # Let OBS' Vulkan/OpenGL game-capture layer hook Steam-launched games
        # without setting per-game launch options.
        OBS_VKCAPTURE = "1";

        # Keep the MangoHud Vulkan layer available for Steam-launched games.
        MANGOHUD = "1";
      };
    });

    extraPackages = with pkgs; [
      obs-studio-plugins.obs-vkcapture
    ];
  };

  home-manager.users.${mainUser}.imports = [
    ../../home/zekurio/hosts/lilith-desktop.nix
  ];

  system.stateVersion = "26.05";
}

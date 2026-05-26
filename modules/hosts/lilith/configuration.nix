{
  inputs,
  pkgs,
  modulesPath,
  ...
}: let
  mainUser = "zekurio";
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "lilith";

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "amd_pstate=guided"
    "acpi_enforce_resources=lax"
  ];
  boot.kernelModules = [
    "kvm-amd"
    "it87"
  ];
  boot.extraModprobeConfig = ''
    options it87 force_id=0x8628
  '';
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
    "amdgpu"
  ];

  hardware.cpu.amd.updateMicrocode = true;

  hardware.amdgpu = {
    opencl.enable = true;
    initrd.enable = true;
  };

  # LACT daemon for overclocking/fan control
  services.lact.enable = true;
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    sbctl
  ];

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
        # Override NixOS' default Limine wallpaper; the terminal background below
        # is made full-screen instead of an inset box.
        wallpapers = [];

        interface.branding = "";

        graphicalTerminal = {
          # Catppuccin Frappé for Limine: https://github.com/catppuccin/limine
          palette = "303446;e78284;a6d189;e5c890;8caaee;f4b8e4;81c8be;c6d0f5";
          brightPalette = "626880;e78284;a6d189;e5c890;8caaee;f4b8e4;81c8be;c6d0f5";
          foreground = "c6d0f5";
          brightForeground = "c6d0f5";
          background = "303446";
          brightBackground = "626880";
          margin = 0;
          marginGradient = 0;
        };
      };
    };
  };

  powerManagement.cpuFreqGovernor = "schedutil";

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

  home-manager.users.${mainUser}.imports = [
    ../../home/zekurio/hosts/lilith-desktop.nix
  ];

  system.stateVersion = "26.05";
}

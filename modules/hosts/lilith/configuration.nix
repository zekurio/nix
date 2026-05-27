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

  # LACT daemon for overclocking/fan control
  services.lact.enable = true;
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    sbctl
  ];

  catppuccin = {
    flavor = "frappe";
    accent = "mauve";
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

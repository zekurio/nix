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

      # TODO(zekurio): enable Limine Secure Boot after preparing sbctl:
      # 1. Rebuild once with this disabled and sbctl installed.
      # 2. In firmware, reset Secure Boot keys / enter Setup Mode.
      # 3. Run: sudo sbctl create-keys
      # 4. Run: sudo sbctl enroll-keys -m -f
      # 5. Set this to true, rebuild, then enable Secure Boot in firmware.
      secureBoot.enable = false;

      # TODO(zekurio): add Windows once Lilith is booting reliably.
      # Windows is on a separate disk, so get its EFI System Partition UUID with:
      #   lsblk -f
      # Then add something like:
      #   extraEntries = ''
      #     /Windows
      #       protocol: efi_chainload
      #       path: uuid(<WINDOWS-ESP-UUID>):/EFI/Microsoft/Boot/bootmgfw.efi
      #   '';
      extraConfig = ''
        # Catppuccin Frappé for Limine: https://github.com/catppuccin/limine
        term_palette: 303446;e78284;a6d189;e5c890;8caaee;f4b8e4;81c8be;c6d0f5
        term_palette_bright: 626880;e78284;a6d189;e5c890;8caaee;f4b8e4;81c8be;c6d0f5
        term_background: 303446
        term_foreground: c6d0f5
        term_background_bright: 626880
        term_foreground_bright: c6d0f5
        interface_branding:
      '';
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

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
    ./disko.nix
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
  ];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub.enable = false;
    systemd-boot.enable = false;
    limine = {
      enable = true;
      efiSupport = true;
      maxGenerations = 3;
    };
  };

  powerManagement.cpuFreqGovernor = "schedutil";

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  programs.dank-material-shell = {
    greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = "/home/${mainUser}";
    };
  };

  programs.dsearch.enable = true;

  programs.niri.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  nix.settings.trusted-users = [mainUser];

  services.pipewire = {
    jack.enable = true;
  };

  home-manager.users.${mainUser}.imports = [
    ../../home/zekurio/lilith-desktop.nix
  ];

  system.stateVersion = "26.05";
}

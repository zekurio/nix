{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  mkWorkstationLimine = import ../_common/workstation/limine.nix;
  resumeDevice = config.fileSystems."/".device;
  resumeOffset = 81850368;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  networking = {
    hostName = "sachiel";
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = ["kvm-amd"];
    kernelParams =
      [
        "quiet"
        "splash"
        "pcie_aspm.policy=powersave"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
      ]
      ++ lib.optional (resumeOffset != null) "resume_offset=${toString resumeOffset}";
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "usbhid"
        "sd_mod"
      ];
      systemd.enable = true;
      verbose = false;
      luks.devices = {
        cryptroot.crypttabExtraOpts = ["tpm2-device=auto"];
      };
    };
    inherit resumeDevice;
    loader = {
      efi.canTouchEfiVariables = true;
      limine = mkWorkstationLimine {
        resolution = "1920x1080x32";
        interfaceResolution = "1920x1080";
      };
    };
  };

  services.xserver.videoDrivers = ["nvidia"];

  powerManagement.powertop.enable = true;

  hardware = {
    asus.battery.chargeUpto = 80;
    nvidia = {
      open = false;
      nvidiaSettings = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
    };
  };

  services = {
    asusd.enable = true;

    # Keep GPU mode switching disabled because this host uses PRIME offload.
    supergfxd.enable = lib.mkForce false;
    power-profiles-daemon.enable = true;
  };

  security.tpm2.enable = true;

  environment = {
    systemPackages = with pkgs; [
      asusctl
      cryptsetup
      e2fsprogs
      pciutils
      powertop
      sbctl
      tpm2-tools
      usbutils
    ];
  };

  # DO NOT TOUCH THIS
  system.stateVersion = "25.05";
}

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  mkWorkstationLimine = import ../_common/workstation/limine.nix;
  amdGpuBusId = "PCI:4@0:0:0";
  nvidiaGpuBusId = "PCI:1@0:0:0";
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

  hardware = {
    nvidia = {
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;
        amdgpuBusId = amdGpuBusId;
        nvidiaBusId = nvidiaGpuBusId;
      };
    };
  };

  security.tpm2.enable = true;

  environment = {
    systemPackages = with pkgs; [
      cryptsetup
      e2fsprogs
      pciutils
      sbctl
      tpm2-tools
      usbutils
    ];
  };

  # DO NOT TOUCH THIS
  system.stateVersion = "25.05";
}

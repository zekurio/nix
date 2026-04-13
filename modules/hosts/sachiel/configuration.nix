{
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  # Replace these with the real decimal bus IDs from `lspci` before deployment.
  amdGpuBusId = "PCI:5@0:0:0";
  nvidiaGpuBusId = "PCI:1@0:0:0";
  # Fill this in after retrieving the swapfile offset from `/swapfile`.
  resumeOffset = null;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  networking = {
    hostName = "sachiel";
    firewall.enable = true;
  };

  modules.desktop.enable = true;
  modules.gaming.enable = true;
  modules.virtualization.enable = true;

  home-manager.users.zekurio = {
    profiles.desktop.enable = true;
    profiles.dev.enable = true;
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
    resumeDevice = "/dev/mapper/cryptroot";
    loader = {
      efi.canTouchEfiVariables = true;
      limine = {
        enable = true;
        maxGenerations = 3;
        resolution = "1920x1080x32";
        # Enable this after key enrollment and a TPM re-enrollment pass.
        secureBoot.enable = false;
        style = {
          interface.resolution = "1920x1080";
          wallpapers = [../../../assets/limine.png];
          graphicalTerminal.background = "FF000000";
        };
        extraConfig = ''
          remember_last_entry: yes
        '';
      };
    };
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware = {
    enableRedistributableFirmware = true;
    firmware = [pkgs.linux-firmware];
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    cpu.amd.updateMicrocode = true;
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
    sessionVariables = {
      LIBVA_DRIVER_NAME = "radeonsi";
    };

    systemPackages = with pkgs; [
      cryptsetup
      e2fsprogs
      pciutils
      sbctl
      tpm2-tools
      usbutils
    ];
  };

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

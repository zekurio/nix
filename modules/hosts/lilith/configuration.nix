{
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking = {
    hostName = "lilith";
    networkmanager.enable = true;
    firewall.enable = true;
  };

  console.useXkbConfig = true;

  catppuccin =
    {
      enable = true;
      autoEnable = false;
      limine.enable = true;
    }
    // import ../../palette.nix;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = ["kvm-amd"];
    kernelParams = [
      "amd_pstate=guided"
    ];
    loader = {
      timeout = 3;
      efi.canTouchEfiVariables = true;
      limine = {
        enable = true;
        efiSupport = true;
        maxGenerations = 10;
        extraEntries = ''
          /Windows Boot Manager
            protocol: efi_boot_entry
            entry: Windows Boot Manager
        '';
        secureBoot = {
          enable = true;
          autoGenerateKeys = true;
          autoEnrollKeys.enable = true;
        };
      };
    };
  };

  hardware = {
    cpu.amd.updateMicrocode = true;
    amdgpu = {
      initrd.enable = true;
      opencl.enable = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa
        mesa.opencl
      ];
    };
  };

  services = {
    printing.enable = true;
    fwupd.enable = true;
    mullvad-vpn.enable = true;
    resolved.enable = true;
    tailscale = {
      enable = true;
      openFirewall = true;
    };
  };

  environment = {
    sessionVariables = {
      LIBVA_DRIVER_NAME = "radeonsi";
    };

    systemPackages = with pkgs; [
      clinfo
      libva-utils
      mesa-demos
      mokutil
      mullvad-vpn
      pciutils
      radeontop
      sbctl
      usbutils
      vulkan-tools
    ];
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
  };

  system.stateVersion = "26.05";
}

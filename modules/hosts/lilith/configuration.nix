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
        # TODO: add a Windows boot entry once the Windows EFI partition is known.
        secureBoot = {
          enable = true;
          autoGenerateKeys = true;
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
    desktopManager.plasma6 = {
      enable = true;
      enableQt5Integration = false;
    };

    displayManager = {
      defaultSession = "plasma";
      plasma-login-manager.enable = true;
      sddm.enable = lib.mkForce false;
    };

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
    };

    pulseaudio.enable = false;
    printing.enable = true;
    fwupd.enable = true;
    mullvad-vpn.enable = true;
    resolved.enable = true;
    tailscale = {
      enable = true;
      openFirewall = true;
    };
  };

  security.rtkit.enable = true;

  programs = {
    kde-pim.enable = false;
    firefox.enable = true;
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

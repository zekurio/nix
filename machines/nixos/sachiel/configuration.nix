{
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ../default.nix
    inputs.dms.nixosModules.greeter
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      "mem_sleep_default=deep"
      "resume_offset=110143488"
    ];
    resumeDevice = "/dev/mapper/cryptroot";
    kernelModules = [
      "kvm-amd"
    ];

    initrd = {
      systemd = {
        enable = true;
        tpm2.enable = true;
      };
      luks.devices.cryptroot = {
        crypttabExtraOpts = [
          "tpm2-device=auto"
          "tpm2-pcrs=7+11"
        ];
      };
    };
  };

  hardware.nvidia = {
    open = false;
    nvidiaSettings = true;
    modesetting.enable = true;
    powerManagement = {
      enable = true;
      finegrained = true;
    };
    prime = {
      amdgpuBusId = "PCI:4@0:0:0";
      nvidiaBusId = "PCI:1@0:0:0";
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };

  networking.hostName = "sachiel";

  powerManagement.enable = true;

  swapDevices = lib.mkForce [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024;
    }
  ];

  security.tpm2.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "suspend-then-hibernate";
  };

  systemd.sleep.extraConfig = ''
    AllowSuspend=yes
    AllowHibernation=yes
    AllowSuspendThenHibernate=yes
    HibernateDelaySec=60min
  '';

  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];

  services.upower.enable = true;

  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
  };

  environment.systemPackages = with pkgs; [
    nvtopPackages.amd
    ryzen-monitor-ng
  ];

  modules.workstation = {
    common.enable = true;
    desktop = {
      enable = true;
      keyboardLayout = "de";
    };
    nfsClient.enable = true;
    bootLimine.enable = true;
    hardware.enable = true;
  };

  system.stateVersion = "25.11"; # DO NOT CHANGE
}

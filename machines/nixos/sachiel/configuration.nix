{
  pkgs,
  inputs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ../default.nix
    inputs.dms.nixosModules.greeter
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
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
      # TODO: replace with values from `lspci -D -d ::03xx` on sachiel
      amdgpuBusId = "PCI:0@0:0:0";
      nvidiaBusId = "PCI:1@0:0:0";
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };

  networking.hostName = "sachiel";

  security.tpm2.enable = true;

  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];

  modules.workstation = {
    common.enable = true;
    desktop = {
      enable = true;
      keyboardLayout = "de";
    };
    nfsClient.enable = true;
    bootLimine.enable = true;
  };

  system.stateVersion = "25.11"; # DO NOT CHANGE
}

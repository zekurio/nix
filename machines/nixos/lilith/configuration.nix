{
  config,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ../default.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [
      "kvm-amd"
      "zenpower"
      "it87"
    ];
    kernelParams = [
      "acpi_enforce_resources=lax"
      "amdgpu.ppfeaturemask=0xffffffff"
    ];
    extraModulePackages = [config.boot.kernelPackages.zenpower];
    extraModprobeConfig = ''
      options it87 force_id=0x8628
    '';
    blacklistedKernelModules = ["k10temp"];

    loader.limine = {
      resolution = "2560x1440x32";
      style.interface.resolution = "2560x1440";
      extraEntries = ''
        /Windows 11
          protocol: efi
          path: boot():/EFI/Microsoft/Boot/Bootmgfw.efi
      '';
    };
  };

  hardware = {
    graphics.extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
    amdgpu.overdrive.enable = true;
  };

  networking = {
    hostName = "lilith";
    nameservers = ["192.168.0.2"];
  };

  services.lact.enable = true;

  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
  };

  environment.systemPackages = with pkgs; [
    nvtopPackages.amd
    ryzen-monitor-ng
  ];

  modules.workstation = {
    common.enable = true;
    desktop.enable = true;
    nfsClient.enable = true;
    bootLimine.enable = true;
    hardware = {
      enable = true;
      coolercontrol.enable = true;
    };
    gaming.enable = true;
    vpn.enable = true;
  };

  system.stateVersion = "25.11"; # DO NOT CHANGE
}

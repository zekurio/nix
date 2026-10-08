{inputs, ...}: {
  flake.modules.nixos.adam = {
    config,
    modulesPath,
    pkgs,
    ...
  }: {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
      inputs.autoaspm.nixosModules.default
      inputs.ucodenix.nixosModules.default
    ];

    nixpkgs.hostPlatform = "x86_64-linux";

    boot = {
      kernelParams = [
        "amd_pstate=guided"
        "microcode.amd_sha_check=off"
        "pcie_aspm=force"
        "pcie_aspm.policy=powersave"
        "i915.enable_guc=3"
        "acpi_enforce_resources=lax"
      ];
      kernelModules = [
        "kvm-amd"
        "zenpower"
        "nct6687"
      ];
      extraModprobeConfig = ''
        softdep nct6687 pre: i2c_i801
        options nct6687
      '';
      extraModulePackages = [
        config.boot.kernelPackages.zenpower
        (config.boot.kernelPackages.callPackage ./_nct6687d.nix {})
      ];
      blacklistedKernelModules = [
        "k10temp"
        "nct6683"
      ];
    };

    hardware = {
      cpu.amd = {
        updateMicrocode = true;
        ryzen-smu.enable = true;
      };
      graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-compute-runtime
          vpl-gpu-rt
          nvtopPackages.intel
        ];
      };
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };

    powerManagement.cpuFreqGovernor = "schedutil";

    services.ucodenix.enable = true;
    services.autoaspm.enable = true;

    environment.systemPackages = with pkgs; [
      ryzen-monitor-ng
      lm_sensors
      intel-gpu-tools
    ];
  };
}

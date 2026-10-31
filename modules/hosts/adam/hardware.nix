{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
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
    '';
    extraModulePackages = [
      config.boot.kernelPackages.zenpower
      config.boot.kernelPackages.nct6687d
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
      ];
    };
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # i915 never allows runtime PM on discrete GPUs, so the A380 would stay in
  # D0 at ~18 W. Every i915 hwmon read wakes the card again, so nothing may
  # poll its sensors; CoolerControl has the device disabled for that reason.
  services.udev.extraRules = ''
    ACTION=="bind", SUBSYSTEM=="pci", DRIVER=="i915", ATTR{power/control}="auto"
  '';

  powerManagement.cpuFreqGovernor = "schedutil";

  services.ucodenix.enable = true;
  services.autoaspm.enable = true;

  environment.systemPackages = with pkgs; [
    ryzen-monitor-ng
    lm_sensors
    intel-gpu-tools
  ];
}
